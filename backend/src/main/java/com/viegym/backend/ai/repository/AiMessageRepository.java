package com.viegym.backend.ai.repository;

import com.viegym.backend.ai.entity.AiMessage;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AiMessageRepository extends JpaRepository<AiMessage, UUID> {
    @Query(value = "select m from AiMessage m where m.conversationId = :conversationId order by m.createdAt, m.id",
        countQuery = "select count(m) from AiMessage m where m.conversationId = :conversationId")
    Page<AiMessage> findPage(UUID conversationId, Pageable pageable);

    /** Lịch sử gửi cho AI: mới nhất trước (service đảo lại), bỏ câu hỏi đang hỏi. */
    @Query("select m from AiMessage m where m.conversationId = :conversationId and m.createdAt <= :before "
        + "and m.id <> :excludeId order by m.createdAt desc, m.id desc")
    List<AiMessage> findLatest(UUID conversationId, java.time.Instant before, UUID excludeId, Pageable pageable);
}
