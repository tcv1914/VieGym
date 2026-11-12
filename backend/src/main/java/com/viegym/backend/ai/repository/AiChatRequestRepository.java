package com.viegym.backend.ai.repository;

import com.viegym.backend.ai.entity.AiChatRequest;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AiChatRequestRepository extends JpaRepository<AiChatRequest, UUID> {
    Optional<AiChatRequest> findByUserIdAndClientRequestId(UUID userId, UUID clientRequestId);

    List<AiChatRequest> findByConversationIdAndStatus(UUID conversationId, AiChatRequest.Status status);

    List<AiChatRequest> findByUserMessageIdIn(Collection<UUID> userMessageIds);

    /** Thời điểm các lần gọi AI gần đây: câu hỏi mới và lần thử lại đều đặt updated_at. */
    @Query("select r.updatedAt from AiChatRequest r where r.userId = :userId and r.updatedAt > :since "
        + "order by r.updatedAt")
    List<Instant> attemptsSince(UUID userId, Instant since);

    /** Số câu hỏi mới (không tính thử lại) từ một thời điểm. */
    long countByUserIdAndCreatedAtGreaterThanEqual(UUID userId, Instant since);
}
