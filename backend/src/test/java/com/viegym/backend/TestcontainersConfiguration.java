package com.viegym.backend;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.test.context.DynamicPropertyRegistrar;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * PostgreSQL riêng cho test (container tạm, không đụng database demo) và cặp khóa JWT
 * sinh mới mỗi lần chạy test, không nằm trong Git.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {
    private static final Path KEY_DIR = generateKeys();

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgresContainer() {
        return new PostgreSQLContainer("postgres:17");
    }

    @Bean
    DynamicPropertyRegistrar jwtKeyProperties() {
        return registry -> {
            registry.add("viegym.auth.private-key-location", () -> KEY_DIR.resolve("private.pem").toUri().toString());
            registry.add("viegym.auth.public-key-location", () -> KEY_DIR.resolve("public.pem").toUri().toString());
        };
    }

    private static Path generateKeys() {
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            KeyPair pair = generator.generateKeyPair();
            Path dir = Files.createTempDirectory("viegym-jwt-test");
            Files.writeString(dir.resolve("private.pem"), pem("PRIVATE KEY", pair.getPrivate().getEncoded()));
            Files.writeString(dir.resolve("public.pem"), pem("PUBLIC KEY", pair.getPublic().getEncoded()));
            return dir;
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException(ex);
        } catch (IOException ex) {
            throw new UncheckedIOException(ex);
        }
    }

    private static String pem(String type, byte[] der) {
        String body = Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(der);
        return "-----BEGIN " + type + "-----\n" + body + "\n-----END " + type + "-----\n";
    }
}
