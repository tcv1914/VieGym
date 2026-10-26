package com.viegym.backend.system;

import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
public class SystemHealthController {
    private final JdbcTemplate jdbcTemplate;

    public SystemHealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        String message = jdbcTemplate.queryForObject(
            "SELECT message FROM system_probe WHERE id = 1",
            String.class
        );
        return Map.of(
            "status", "UP",
            "service", "viegym-backend",
            "database", "UP",
            "message", message
        );
    }
}
