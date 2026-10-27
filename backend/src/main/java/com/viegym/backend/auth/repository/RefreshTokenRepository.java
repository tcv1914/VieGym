package com.viegym.backend.auth.repository;

import com.viegym.backend.auth.entity.RefreshToken;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {
    /**
     * SELECT ... FOR UPDATE: request refresh thứ hai cùng token phải chờ request đầu
     * commit, rồi thấy token đã consumed.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        select t from RefreshToken t
        join fetch t.session s
        join fetch s.user
        where t.tokenHash = :tokenHash
        """)
    Optional<RefreshToken> findForUpdate(String tokenHash);

    @Query("select t from RefreshToken t join fetch t.session where t.tokenHash = :tokenHash")
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        update RefreshToken t set t.revokedAt = :now
        where t.session.id = :sessionId and t.revokedAt is null
        """)
    int revokeAllOfSession(UUID sessionId, Instant now);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        update RefreshToken t set t.revokedAt = :now
        where t.session.id in (select s.id from AuthSession s where s.user.id = :userId)
          and t.revokedAt is null
        """)
    int revokeAllOfUser(UUID userId, Instant now);
}
