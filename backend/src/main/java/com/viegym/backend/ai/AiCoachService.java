package com.viegym.backend.ai;

import com.viegym.backend.ai.AiClient.AiCallException;
import com.viegym.backend.ai.AiClient.HistoryMessage;
import com.viegym.backend.ai.dto.AiDtos.ChatRequest;
import com.viegym.backend.ai.dto.AiDtos.ChatResult;
import com.viegym.backend.ai.dto.AiDtos.ConversationItem;
import com.viegym.backend.ai.dto.AiDtos.ConversationRef;
import com.viegym.backend.ai.dto.AiDtos.HistoryItem;
import com.viegym.backend.ai.dto.AiDtos.MessageItem;
import com.viegym.backend.ai.entity.AiChatRequest;
import com.viegym.backend.ai.entity.AiChatRequest.Status;
import com.viegym.backend.ai.entity.AiConversation;
import com.viegym.backend.ai.entity.AiMessage;
import com.viegym.backend.ai.repository.AiChatRequestRepository;
import com.viegym.backend.ai.repository.AiConversationRepository;
import com.viegym.backend.ai.repository.AiMessageRepository;
import com.viegym.backend.auth.entity.User;
import com.viegym.backend.auth.repository.UserRepository;
import com.viegym.backend.common.exception.ApiException;
import com.viegym.backend.common.web.PageResponse;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * UC10 (docs/27). Luồng BR-AI05: (1) giao dịch ngắn — khóa users, chống gửi lặp, giới hạn tần suất,
 * lưu câu hỏi + request PROCESSING, commit; (2) dựng context và gọi ai-service <b>ngoài</b> giao dịch;
 * (3) giao dịch ngắn — lưu câu trả lời + SUCCEEDED hoặc FAILED + mã lỗi. Câu hỏi không mất khi AI lỗi.
 */
@Service
public class AiCoachService {
    public static final int MAX_MESSAGE_LENGTH = 2000;
    static final int MAX_CONVERSATION_PAGE = 50;
    static final int MAX_MESSAGE_PAGE = 100;

    private final AiProperties properties;
    private final AiClient aiClient;
    private final AiContextBuilder contextBuilder;
    private final UserRepository userRepository;
    private final AiConversationRepository conversationRepository;
    private final AiMessageRepository messageRepository;
    private final AiChatRequestRepository requestRepository;
    private final TransactionTemplate tx;
    private final Clock clock;
    private final String systemPrompt;

    public AiCoachService(AiProperties properties, AiClient aiClient, AiContextBuilder contextBuilder,
                          UserRepository userRepository, AiConversationRepository conversationRepository,
                          AiMessageRepository messageRepository, AiChatRequestRepository requestRepository,
                          PlatformTransactionManager transactionManager, Clock clock) {
        this.properties = properties;
        this.aiClient = aiClient;
        this.contextBuilder = contextBuilder;
        this.userRepository = userRepository;
        this.conversationRepository = conversationRepository;
        this.messageRepository = messageRepository;
        this.requestRepository = requestRepository;
        this.tx = new TransactionTemplate(transactionManager);
        this.clock = clock;
        this.systemPrompt = loadSystemPrompt();
    }

    private static String loadSystemPrompt() {
        try {
            return new ClassPathResource("ai/coach-system-prompt.txt").getContentAsString(StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /** Kết quả bước 1: đã có kết quả (gửi lặp SUCCEEDED) hoặc cần gọi AI cho lần thử {@code attempt}. */
    private record Begin(ChatResult done, UUID requestId, int attempt, UUID conversationId, UUID userMessageId,
                         Instant askedAt) {
    }

    public ChatResult chat(UUID userId, ChatRequest request) {
        if (!properties.enabled()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_DISABLED", "AI Coach đang tạm tắt");
        }
        String message = request.message().strip();
        if (message.isEmpty()) {
            throw ApiException.validation("message", "Vui lòng nhập câu hỏi");
        }
        if (message.codePointCount(0, message.length()) > MAX_MESSAGE_LENGTH) {
            throw ApiException.validation("message", "Câu hỏi tối đa 2.000 ký tự");
        }

        Begin begin = tx.execute(status -> begin(userId, request, message));
        if (begin.done() != null) {
            return begin.done();
        }

        AiClient.Reply reply;
        String errorCode;
        try {
            User user = userRepository.findById(userId).orElseThrow(AiCoachService::userNotFound);
            reply = aiClient.chat(new AiClient.Call(begin.requestId(), systemPrompt, contextBuilder.build(user),
                history(begin), message));
            errorCode = null;
        } catch (AiCallException e) {
            reply = null;
            errorCode = e.getCode();
        } catch (RuntimeException e) {
            // Lỗi bất ngờ khi dựng context/gọi: vẫn đóng request để hội thoại không bị khóa.
            reply = null;
            errorCode = AiCallException.UPSTREAM;
        }

        AiClient.Reply finalReply = reply;
        String finalError = errorCode;
        ChatResult result = tx.execute(status -> finish(userId, begin, finalReply, finalError));
        if (result.status() == Status.FAILED) {
            throw aiFailure(finalError == null ? AiCallException.UPSTREAM : finalError, begin);
        }
        return result;
    }

    private Begin begin(UUID userId, ChatRequest request, String message) {
        User user = userRepository.findForUpdate(userId).orElseThrow(AiCoachService::userNotFound);
        Instant now = now();
        AiChatRequest existing = requestRepository.findByUserIdAndClientRequestId(userId, request.clientRequestId())
            .orElse(null);
        if (existing != null) {
            AiMessage question = messageRepository.findById(existing.getUserMessageId()).orElseThrow();
            boolean samePayload = question.getContent().equals(message)
                && (request.conversationId() == null || request.conversationId().equals(existing.getConversationId()));
            if (!samePayload) {
                throw new ApiException(HttpStatus.CONFLICT, "CLIENT_REQUEST_ID_REUSED",
                    "Mã yêu cầu đã dùng cho một câu hỏi khác");
            }
            expireIfStale(existing, now);
            switch (existing.getStatus()) {
                case SUCCEEDED -> {
                    return new Begin(result(existing), null, 0, null, null, null);
                }
                case PROCESSING -> throw inProgress();
                case FAILED -> {
                    checkMinuteLimit(userId, now);
                    checkConversationFree(existing.getConversationId(), existing.getId(), now);
                    existing.retry(now);
                    requestRepository.flush();
                    return new Begin(null, existing.getId(), existing.getAttemptCount(),
                        existing.getConversationId(), existing.getUserMessageId(), question.getCreatedAt());
                }
                default -> throw new IllegalStateException();
            }
        }

        checkMinuteLimit(userId, now);
        checkDayLimit(user, now);
        AiConversation conversation;
        if (request.conversationId() != null) {
            conversation = conversationRepository.findByIdAndUserId(request.conversationId(), userId)
                .orElseThrow(AiCoachService::conversationNotFound);
            checkConversationFree(conversation.getId(), null, now);
            conversation.touch(now);
        } else {
            conversation = conversationRepository.save(new AiConversation(userId, message, now));
        }
        AiMessage question = messageRepository.save(
            new AiMessage(conversation.getId(), AiMessage.Role.USER, message, now));
        AiChatRequest created = requestRepository.save(
            new AiChatRequest(userId, request.clientRequestId(), conversation.getId(), question.getId(), now));
        requestRepository.flush();
        return new Begin(null, created.getId(), created.getAttemptCount(), conversation.getId(), question.getId(),
            now);
    }

    private ChatResult finish(UUID userId, Begin begin, AiClient.Reply reply, String errorCode) {
        userRepository.findForUpdate(userId).orElseThrow(AiCoachService::userNotFound);
        AiChatRequest request = requestRepository.findById(begin.requestId()).orElseThrow();
        Instant now = now();
        // Trong lúc gọi AI, request đã bị coi là quá hạn và được thử lại ở nơi khác: kết quả này cũ.
        if (request.getStatus() != Status.PROCESSING || request.getAttemptCount() != begin.attempt()) {
            if (request.getStatus() == Status.SUCCEEDED) {
                return result(request);
            }
            throw inProgress();
        }
        AiConversation conversation = conversationRepository.findById(request.getConversationId()).orElseThrow();
        if (reply != null) {
            AiMessage answer = messageRepository.save(new AiMessage(conversation.getId(), AiMessage.Role.ASSISTANT,
                reply.content(), now));
            request.succeed(answer.getId(), truncate(reply.model(), 100), reply.promptTokens(),
                reply.completionTokens(), now);
        } else {
            request.fail(errorCode, now);
        }
        conversation.touch(now);
        requestRepository.flush();
        return result(request);
    }

    /** Tối đa N tin gần nhất trước câu hỏi hiện tại, theo thứ tự thời gian (BR-AI03). */
    private List<HistoryMessage> history(Begin begin) {
        if (properties.historySize() == 0) {
            return List.of();
        }
        List<AiMessage> latest = new ArrayList<>(messageRepository.findLatest(begin.conversationId(), begin.askedAt(),
            begin.userMessageId(), PageRequest.of(0, properties.historySize())));
        Collections.reverse(latest);
        return latest.stream().map(m -> new HistoryMessage(m.getRole().name(), m.getContent())).toList();
    }

    @Transactional
    public PageResponse<ConversationItem> conversations(UUID userId, int page, int size) {
        checkPage(page, size, MAX_CONVERSATION_PAGE);
        return PageResponse.of(conversationRepository.findPage(userId, PageRequest.of(page, size)),
            c -> new ConversationItem(c.getId(), c.getTitle(), c.getLastMessageAt(), c.getCreatedAt()));
    }

    /** Request quá hạn được đánh dấu FAILED / AI_TIMEOUT ngay khi đọc (BR-AI07). */
    @Transactional
    public PageResponse<HistoryItem> messages(UUID userId, UUID conversationId, int page, int size) {
        checkPage(page, size, MAX_MESSAGE_PAGE);
        conversationRepository.findByIdAndUserId(conversationId, userId)
            .orElseThrow(AiCoachService::conversationNotFound);
        Page<AiMessage> messages = messageRepository.findPage(conversationId, PageRequest.of(page, size));
        List<UUID> questionIds = messages.getContent().stream().filter(m -> m.getRole() == AiMessage.Role.USER)
            .map(AiMessage::getId).toList();
        Instant now = now();
        Map<UUID, AiChatRequest> requests = questionIds.isEmpty() ? Map.of()
            : requestRepository.findByUserMessageIdIn(questionIds).stream()
                .peek(r -> expireIfStale(r, now))
                .collect(Collectors.toMap(AiChatRequest::getUserMessageId, Function.identity()));
        return PageResponse.of(messages, m -> {
            AiChatRequest r = requests.get(m.getId());
            return new HistoryItem(m.getId(), m.getRole(), m.getContent(), m.getCreatedAt(),
                r == null ? null : r.getStatus(), r == null ? null : r.getClientRequestId(),
                r == null ? null : r.getErrorCode());
        });
    }

    private void expireIfStale(AiChatRequest request, Instant now) {
        if (request.isStale(now)) {
            request.fail(AiCallException.TIMEOUT, now);
        }
    }

    /** Một câu hỏi đang chờ AI mỗi hội thoại: lượt sau phải có lịch sử đầy đủ. */
    private void checkConversationFree(UUID conversationId, UUID exceptRequestId, Instant now) {
        for (AiChatRequest r : requestRepository.findByConversationIdAndStatus(conversationId, Status.PROCESSING)) {
            expireIfStale(r, now);
            if (r.getStatus() == Status.PROCESSING && !r.getId().equals(exceptRequestId)) {
                throw inProgress();
            }
        }
    }

    /** BR-AI04/BR-AI10: tối đa N lần gọi AI/phút (câu hỏi mới và thử lại đều tính). */
    private void checkMinuteLimit(UUID userId, Instant now) {
        List<Instant> recent = requestRepository.attemptsSince(userId, now.minus(Duration.ofMinutes(1)));
        if (recent.size() >= properties.perMinute()) {
            long wait = Duration.between(now, recent.get(recent.size() - properties.perMinute())
                .plus(Duration.ofMinutes(1))).toSeconds() + 1;
            throw rateLimited("Bạn hỏi hơi nhanh, vui lòng chờ một chút rồi thử lại", wait);
        }
    }

    /** BR-AI04: tối đa N câu hỏi mới/ngày theo múi giờ user; thử lại không tính thêm. */
    private void checkDayLimit(User user, Instant now) {
        ZoneId zone = ZoneId.of(user.getTimezone());
        LocalDate today = LocalDate.ofInstant(now, zone);
        Instant dayStart = today.atStartOfDay(zone).toInstant();
        if (requestRepository.countByUserIdAndCreatedAtGreaterThanEqual(user.getId(), dayStart)
            >= properties.perDay()) {
            long wait = Duration.between(now, today.plusDays(1).atStartOfDay(zone).toInstant()).toSeconds() + 1;
            throw rateLimited("Bạn đã dùng hết " + properties.perDay() + " câu hỏi hôm nay, hãy quay lại vào ngày mai",
                wait);
        }
    }

    private ChatResult result(AiChatRequest r) {
        AiConversation c = conversationRepository.findById(r.getConversationId()).orElseThrow();
        MessageItem question = messageRepository.findById(r.getUserMessageId()).map(MessageItem::of).orElseThrow();
        MessageItem answer = r.getAssistantMessageId() == null ? null
            : messageRepository.findById(r.getAssistantMessageId()).map(MessageItem::of).orElse(null);
        return new ChatResult(r.getId(), r.getClientRequestId(), r.getStatus(), new ConversationRef(c.getId(),
            c.getTitle()), question, answer);
    }

    private static ApiException aiFailure(String code, Begin begin) {
        HttpStatus status = AiCallException.TIMEOUT.equals(code) ? HttpStatus.GATEWAY_TIMEOUT : HttpStatus.BAD_GATEWAY;
        String message = switch (code) {
            case AiCallException.TIMEOUT -> "AI phản hồi quá lâu. Câu hỏi đã được lưu, bạn có thể thử lại";
            case AiCallException.EMPTY -> "AI không trả lời được câu này. Câu hỏi đã được lưu, bạn có thể thử lại";
            default -> "Dịch vụ AI đang gặp sự cố. Câu hỏi đã được lưu, bạn có thể thử lại";
        };
        Map<String, Object> details = new LinkedHashMap<>();
        details.put("requestId", begin.requestId());
        details.put("conversationId", begin.conversationId());
        details.put("userMessageId", begin.userMessageId());
        details.put("retryable", true);
        return new ApiException(status, code, message, null, details);
    }

    private static ApiException rateLimited(String message, long retryAfterSeconds) {
        return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", message, null,
            Map.of("retryAfterSeconds", Math.max(1, retryAfterSeconds)));
    }

    private static ApiException inProgress() {
        return new ApiException(HttpStatus.CONFLICT, "AI_REQUEST_IN_PROGRESS",
            "AI đang trả lời câu hỏi trước, vui lòng chờ");
    }

    private static void checkPage(int page, int size, int max) {
        if (page < 0) {
            throw ApiException.validation("page", "Số trang phải từ 0");
        }
        if (size < 1 || size > max) {
            throw ApiException.validation("size", "Kích thước trang phải từ 1 đến " + max);
        }
    }

    private static String truncate(String value, int max) {
        return value == null || value.length() <= max ? value : value.substring(0, max);
    }

    private Instant now() {
        return clock.instant().truncatedTo(ChronoUnit.MICROS);
    }

    private static ApiException conversationNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy hội thoại");
    }

    private static ApiException userNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy tài khoản");
    }
}
