package com.viegym.backend.common.security;

import java.util.List;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

public class SessionAuthentication extends AbstractAuthenticationToken {
    private final AuthenticatedUser principal;
    private final Jwt jwt;

    public SessionAuthentication(AuthenticatedUser principal, Jwt jwt) {
        // Quyền lấy từ role hiện tại trong database, không từ claim của token.
        super(List.of(new SimpleGrantedAuthority("ROLE_" + principal.role().name())));
        this.principal = principal;
        this.jwt = jwt;
        setAuthenticated(true);
    }

    @Override
    public AuthenticatedUser getPrincipal() {
        return principal;
    }

    @Override
    public Jwt getCredentials() {
        return jwt;
    }

    @Override
    public String getName() {
        return principal.userId().toString();
    }
}
