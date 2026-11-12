package com.viegym.backend.ai.repository;

import com.viegym.backend.ai.entity.AiConversation;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface AiConversationRepository extends JpaRepository<AiConversation, UUID> {
    /** Luôn kèm user: hội thoại của người khác trả rỗng như không tồn tại (AI-BR03). */
    Optional<AiConversation> findByIdAndUserId(UUID id, UUID userId);

    @Query(value = "select c from AiConversation c where c.userId = :userId order by c.lastMessageAt desc, c.id desc",
        countQuery = "select count(c) from AiConversation c where c.userId = :userId")
    Page<AiConversation> findPage(UUID userId, Pageable pageable);
}
