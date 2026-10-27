package com.viegym.backend.auth.repository;

import com.viegym.backend.auth.entity.User;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID> {
    /** Email phải được chuẩn hóa trước khi gọi. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    /** SELECT ... FOR UPDATE: điểm khóa chung cho các thao tác ghi dữ liệu một-mỗi-user. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.id = :id")
    Optional<User> findForUpdate(UUID id);
}
