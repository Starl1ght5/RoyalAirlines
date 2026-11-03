package com.stellargear.royal_airlines.Config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Autentica las rutas internas con la cabecera {@code X-API-Key}, separada del JWT de la app.
 *
 * <p>Solo actua sobre {@code /internal/**}: el microservicio de recomendaciones (o cualquier
 * integracion servidor-servidor) se identifica con la misma {@code INTERNAL_API_KEY} que
 * aparece en su {@code .env}. La comparacion es en tiempo constante para no filtrar la clave
 * por tiempos de respuesta.</p>
 *
 * <p>Si la clave no esta configurada en el backend la peticion se rechaza con 503, igual que
 * hace la API de Python: un despliegue sin la clave compartida no deja el internal abierto.</p>
 */
@Component
public class InternalApiKeyFilter extends OncePerRequestFilter {

    private static final String INTERNAL_PREFIX = "/internal/";
    private static final String HEADER = "X-API-Key";

    /** Clave compartida con los servicios internos; vacia significa «internal deshabilitado». */
    @Value("${royal.internal-api-key:}")
    private String internalApiKey;

    /**
     * Decide si la peticion corresponde a una ruta interna.
     *
     * @param request peticion HTTP entrante.
     * @return {@code true} si no es una ruta {@code /internal/**} y el filtro debe saltarse.
     */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith(INTERNAL_PREFIX);
    }

    /**
     * Valida la API key y, si es correcta, deja un principal {@code ROLE_INTERNAL} en el contexto.
     *
     * @param request peticion HTTP entrante.
     * @param response respuesta saliente.
     * @param chain siguiente filtro de la cadena.
     * @throws ServletException si la cadena falla.
     * @throws IOException si la lectura o escritura falla.
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {

        if (internalApiKey == null || internalApiKey.isBlank()) {
            reject(response, HttpStatus.SERVICE_UNAVAILABLE, "INTERNAL_API_KEY no esta configurada");
            return;
        }

        String provided = request.getHeader(HEADER);
        boolean valid = provided != null && MessageDigest.isEqual(
                provided.getBytes(StandardCharsets.UTF_8), internalApiKey.getBytes(StandardCharsets.UTF_8));

        if (!valid) {
            reject(response, HttpStatus.UNAUTHORIZED, "API key invalida");
            return;
        }

        var authentication = new UsernamePasswordAuthenticationToken(
                "internal", null, java.util.List.of(new SimpleGrantedAuthority("ROLE_INTERNAL")));
        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
        SecurityContextHolder.getContext().setAuthentication(authentication);

        chain.doFilter(request, response);
    }

    private void reject(HttpServletResponse response, HttpStatus status, String message) throws IOException {
        response.setStatus(status.value());
        response.setContentType("application/json");
        response.getWriter().write("{\"error\":\"" + message + "\"}");
    }
}
