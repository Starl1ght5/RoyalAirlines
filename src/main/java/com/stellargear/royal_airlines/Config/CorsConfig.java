package com.stellargear.royal_airlines.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * Configura los origenes permitidos para el navegador.
 *
 * <p>Se integra con Spring Security mediante {@code .cors(Customizer.withDefaults())}, de modo que
 * las peticiones de preflight (OPTIONS) no se bloquean antes de llegar a los controladores.</p>
 */
@Configuration
public class CorsConfig {

    /**
     * Define la fuente de configuracion CORS aplicada a todas las rutas de la API.
     *
     * @return origenes, metodos y cabeceras permitidos, con credenciales habilitadas y una
     *         duracion de cache de preflight de una hora.
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:5173", "https://royalairlines.netlify.app"));
        config.setAllowedMethods(List.of("GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}