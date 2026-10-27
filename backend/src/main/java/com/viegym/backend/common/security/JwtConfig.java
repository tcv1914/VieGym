package com.viegym.backend.common.security;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import java.io.IOException;
import java.io.InputStream;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.util.List;
import java.util.Objects;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.core.io.Resource;
import org.springframework.security.converter.RsaKeyConverters;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.JwtAudienceValidator;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTypeValidator;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

/** Ký access token RS256: private key chỉ ở backend, public key để xác minh. */
@Configuration
public class JwtConfig {
    public static final String SESSION_CLAIM = "sid";

    @Bean
    RSAKey jwtSigningKey(AuthProperties properties) throws JOSEException {
        RSAPublicKey publicKey = readKey(properties.publicKeyLocation(), RsaKeyConverters.x509());
        RSAPrivateKey privateKey = readKey(properties.privateKeyLocation(), RsaKeyConverters.pkcs8());
        return new RSAKey.Builder(publicKey).privateKey(privateKey).keyIDFromThumbprint().build();
    }

    @Bean
    JwtEncoder jwtEncoder(RSAKey jwtSigningKey) {
        return new NimbusJwtEncoder(new ImmutableJWKSet<>(new JWKSet(jwtSigningKey)));
    }

    @Bean
    JwtDecoder jwtDecoder(RSAKey jwtSigningKey, AuthProperties properties) throws JOSEException {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withPublicKey(jwtSigningKey.toRSAPublicKey())
            .signatureAlgorithm(SignatureAlgorithm.RS256)
            .build();
        // Mặc định đã có kiểm tra exp/nbf; thêm iss, aud, typ và các claim bắt buộc.
        decoder.setJwtValidator(JwtValidators.createDefaultWithValidators(List.of(
            JwtTypeValidator.jwt(),
            new JwtIssuerValidator(properties.issuer()),
            new JwtAudienceValidator(properties.audience()),
            new JwtClaimValidator<>(JwtClaimNames.EXP, Objects::nonNull),
            new JwtClaimValidator<>(JwtClaimNames.SUB, Objects::nonNull),
            new JwtClaimValidator<>(SESSION_CLAIM, Objects::nonNull)
        )));
        return decoder;
    }

    private static <T> T readKey(Resource location, Converter<InputStream, T> converter) {
        try (InputStream in = location.getInputStream()) {
            return converter.convert(in);
        } catch (IOException ex) {
            throw new IllegalStateException(
                "Không đọc được khóa JWT tại " + location + ". Xem docs/09-auth-design.md §6 để tạo khóa.", ex);
        }
    }
}
