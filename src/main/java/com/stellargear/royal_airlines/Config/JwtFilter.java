package com.stellargear.royal_airlines.Config;

import com.stellargear.royal_airlines.Services.CustomUserDetailsService;
import com.stellargear.royal_airlines.Services.JwtService;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.ApplicationContext;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Filtro que autentica cada peticion a partir del token JWT de la cabecera {@code Authorization}.
 *
 * <p>Si el token es valido y corresponde a un usuario existente, carga sus permisos en el
 * contexto de seguridad. En cualquier otro caso deja la peticion sin autenticar, de modo que
 * Spring Security responda 401 en lugar de propagar un error.</p>
 */
@Component
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private final ApplicationContext applicationContext;
    private final JwtService jwtService;

    /**
     * Intenta autenticar la peticion con el token JWT y continua la cadena de filtros.
     *
     * <p>Un token invalido o de un usuario que ya no existe se registra en nivel debug y la
     * peticion se trata como no autenticada, nunca como un error del servidor.</p>
     *
     * @param request peticion HTTP entrante.
     * @param response respuesta HTTP saliente.
     * @param filterChain siguiente filtro de la cadena.
     * @throws ServletException si el procesamiento de la peticion falla.
     * @throws IOException si la lectura o escritura de la peticion falla.
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");
        String token = null;
        String username = null;

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            token = authHeader.substring(7);

            try {
                username = jwtService.extractUserName(token);
            } catch (JwtException | IllegalArgumentException e) {
                logger.debug("Token JWT invalido, se ignora: " + e.getMessage());
            }
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            try {
                UserDetails userDetails = applicationContext.getBean(CustomUserDetailsService.class)
                        .loadUserByUsername(username);

                if (jwtService.validateToken(token, userDetails)) {
                    UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
                    authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            } catch (UsernameNotFoundException e) {
                logger.debug("El token corresponde a un usuario que ya no existe, se ignora");
            }
        }

        filterChain.doFilter(request, response);
    }
}