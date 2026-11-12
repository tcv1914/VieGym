package com.viegym.backend.ai;

import com.viegym.backend.ai.dto.AiDtos.ChatRequest;
import com.viegym.backend.ai.dto.AiDtos.ChatResult;
import com.viegym.backend.ai.dto.AiDtos.ConversationItem;
import com.viegym.backend.ai.dto.AiDtos.HistoryItem;
import com.viegym.backend.common.security.AuthenticatedUser;
import com.viegym.backend.common.web.PageResponse;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** docs/05 §12. Hội thoại của người khác → 404 (AI-BR03). */
@RestController
@RequestMapping("/api/v1/ai")
@EnableConfigurationProperties(AiProperties.class)
public class AiCoachController {
    private final AiCoachService service;

    public AiCoachController(AiCoachService service) {
        this.service = service;
    }

    /** 200 cả khi gửi lặp một câu đã SUCCEEDED (BR-AI06). */
    @PostMapping("/coach/chat")
    public ChatResult chat(@AuthenticationPrincipal AuthenticatedUser currentUser,
                           @Valid @RequestBody ChatRequest request) {
        return service.chat(currentUser.userId(), request);
    }

    @GetMapping("/conversations")
    public PageResponse<ConversationItem> conversations(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                                        @RequestParam(defaultValue = "0") int page,
                                                        @RequestParam(defaultValue = "20") int size) {
        return service.conversations(currentUser.userId(), page, size);
    }

    @GetMapping("/conversations/{id}/messages")
    public PageResponse<HistoryItem> messages(@AuthenticationPrincipal AuthenticatedUser currentUser,
                                              @PathVariable UUID id,
                                              @RequestParam(defaultValue = "0") int page,
                                              @RequestParam(defaultValue = "50") int size) {
        return service.messages(currentUser.userId(), id, page, size);
    }
}
