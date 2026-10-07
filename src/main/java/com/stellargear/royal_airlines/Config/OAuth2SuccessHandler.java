package com.stellargear.royal_airlines.Config;

import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Services.GoogleAccountService;
import com.stellargear.royal_airlines.Services.JwtService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Maneja el login con Google en el flujo web basado en redireccion.
 *
 * <p>Resuelve el usuario local a partir de los datos de Google, genera el JWT de Royal Airlines
 * y lo entrega al frontend como fragmento de la URL. El flujo movil, donde el cliente envia el
 * {@code idToken}, se atiende en {@code GoogleAuthController}.</p>
 */
@Component
@RequiredArgsConstructor
public class OAuth2SuccessHandler implements AuthenticationSuccessHandler {

    private static final Logger logger = LoggerFactory.getLogger(OAuth2SuccessHandler.class);

    private final GoogleAccountService googleAccountService;
    private final JwtService jwtService;

    /** URL del frontend a la que se redirige tras un login exitoso. */
    @Value("${app.frontend.oauth-success-url}")
    private String successUrl;

    /** URL del frontend a la que se redirige cuando Google rechaza la identidad. */
    @Value("${app.frontend.oauth-failure-url}")
    private String failureUrl;

    /**
     * Resuelve la cuenta, emite el token y redirige al frontend.
     *
     * @param request peticion HTTP que completo el login con Google.
     * @param response respuesta HTTP donde se escribe la redireccion.
     * @param authentication autenticacion de OAuth2 ya validada por Spring Security.
     * @throws IOException si no se puede escribir la redireccion en la respuesta.
     */
    @Override
    public void onAuthenticationSuccess(HttpServletRequest request,
                                         HttpServletResponse response,
                                         Authentication authentication) throws IOException {

        OAuth2User googleUser = (OAuth2User) authentication.getPrincipal();

        try {
            User user = googleAccountService.resolveUser(
                    googleUser.getAttribute("sub"),
                    googleUser.getAttribute("email"),
                    googleUser.getAttribute("email_verified"));

            String token = jwtService.generateToken(user);
            response.sendRedirect(successUrl + "#token=" + URLEncoder.encode(token, StandardCharsets.UTF_8));

        } catch (ResponseStatusException e) {
            logger.warn("Login con Google rechazado: {}", e.getReason());
            response.sendRedirect(failureUrl);
        }
    }
}