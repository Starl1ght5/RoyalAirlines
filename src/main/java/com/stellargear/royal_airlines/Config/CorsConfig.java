package com.stellargear.royal_airlines.Config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Configura los origenes permitidos para el navegador.
 *
 * <p>Se integra con Spring Security mediante {@code .cors(Customizer.withDefaults())}, de modo que
 * las peticiones de preflight (OPTIONS) no se bloquean antes de llegar a los controladores.</p>
 *
 * <p>Los origenes se leen de {@code app.cors.allowed-origins} (variable {@code CORS_ALLOWED_ORIGINS},
 * separados por coma). CORS solo afecta a clientes web: una app movil nativa no lo necesita.</p>
 */
@Configuration
public class CorsConfig {

    private final List<String> allowedOriginPatterns;

    /**
     * Lee los origenes permitidos desde la configuracion.
     *
     * @param allowedOrigins patrones de origen separados por coma.
     */
    public CorsConfig(@Value("${app.cors.allowed-origins}") String allowedOrigins) {
        this.allowedOriginPatterns = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toList();
    }

    /**
     * Define la fuente de configuracion CORS aplicada a todas las rutas de la API.
     *
     * @return origenes, metodos y cabeceras permitidos, con credenciales habilitadas y una
     *         duracion de cache de preflight de una hora.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(allowedOriginPatterns);
        config.setAllowedMethods(List.of("GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
