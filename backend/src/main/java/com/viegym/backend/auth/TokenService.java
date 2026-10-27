package com.viegym.backend.auth;

import com.viegym.backend.common.security.AuthProperties;
import com.viegym.backend.common.security.JwtConfig;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

@Service
public class TokenService {
    private static final int REFRESH_TOKEN_BYTES = 32;

    private final JwtEncoder jwtEncoder;
    private final AuthProperties properties;
    private final SecureRandom secureRandom = new SecureRandom();

    public TokenService(JwtEncoder jwtEncoder, AuthProperties properties) {
        this.jwtEncoder = jwtEncoder;
        this.properties = properties;
    }

    /** Chỉ chứa định danh; role, email, dữ liệu sức khỏe không nằm trong JWT. */
    public String issueAccessToken(UUID userId, UUID sessionId, Instant now) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(properties.issuer())
            .audience(List.of(properties.audience()))
            .subject(userId.toString())
            .claim(JwtConfig.SESSION_CLAIM, sessionId.toString())
            .issuedAt(now)
            .expiresAt(now.plus(properties.accessTokenTtl()))
            .build();
        JwsHeader header = JwsHeader.with(SignatureAlgorithm.RS256).type("JWT").build();
        return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    public long accessTokenTtlSeconds() {
        return properties.accessTokenTtl().toSeconds();
    }

    /** Chuỗi ngẫu nhiên 256 bit, URL-safe. Chỉ trả cho client, không lưu. */
    public String newRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * SHA-256 đủ cho token ngẫu nhiên entropy cao. Không dùng cách này cho mật khẩu
     * người dùng — mật khẩu đi qua PasswordEncoder.
     */
    public static String hashRefreshToken(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("JVM thiếu SHA-256", ex);
        }
    }
}
