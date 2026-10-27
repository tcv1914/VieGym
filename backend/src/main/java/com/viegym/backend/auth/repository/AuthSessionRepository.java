package com.viegym.backend.auth.repository;

import com.viegym.backend.auth.entity.AuthSession;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface AuthSessionRepository extends JpaRepository<AuthSession, UUID> {
    @Query("select s from AuthSession s join fetch s.user where s.id = :id")
    Optional<AuthSession> findWithUserById(UUID id);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update AuthSession s set s.revokedAt = :now where s.id = :id and s.revokedAt is null")
    int revoke(UUID id, Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update AuthSession s set s.revokedAt = :now where s.user.id = :userId and s.revokedAt is null")
    int revokeAllOfUser(UUID userId, Instant now);
}
