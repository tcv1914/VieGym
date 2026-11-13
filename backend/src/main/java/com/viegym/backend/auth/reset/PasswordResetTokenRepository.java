package com.viegym.backend.auth.reset;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, UUID> {
    /** Gọi khi đã khóa dòng users của chủ mã, nên không cần khóa riêng dòng mã. */
    Optional<PasswordResetToken> findFirstByUserIdAndUsedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(
        UUID userId, Instant now);

    long countByUserIdAndCreatedAtAfter(UUID userId, Instant since);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update PasswordResetToken t set t.usedAt = :now where t.userId = :userId and t.usedAt is null")
    int invalidateAllOfUser(UUID userId, Instant now);
}
