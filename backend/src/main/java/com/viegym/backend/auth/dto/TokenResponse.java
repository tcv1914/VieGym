package com.viegym.backend.auth.dto;

public record TokenResponse(
    String tokenType,
    String accessToken,
    long accessTokenExpiresIn,
    String refreshToken,
    UserResponse user
) {
    @Override
    public String toString() {
        return "TokenResponse[user=" + user.id() + "]";
    }
}
