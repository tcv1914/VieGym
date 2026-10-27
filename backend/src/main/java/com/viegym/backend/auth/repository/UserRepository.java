package com.viegym.backend.auth.repository;

import com.viegym.backend.auth.entity.User;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {
    /** Email phải được chuẩn hóa trước khi gọi. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);
}
