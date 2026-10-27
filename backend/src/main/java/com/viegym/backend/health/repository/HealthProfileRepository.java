package com.viegym.backend.health.repository;

import com.viegym.backend.health.entity.HealthProfile;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HealthProfileRepository extends JpaRepository<HealthProfile, UUID> {
    Optional<HealthProfile> findByUserId(UUID userId);

    boolean existsByUserId(UUID userId);
}
