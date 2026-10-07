package com.stellargear.royal_airlines.Config;

import com.stellargear.royal_airlines.Services.CustomUserDetailsService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Define la cadena de seguridad de la aplicacion.
 *
 * <p>Las sesiones son sin estado y la autenticacion se basa en tokens JWT. El orden de las
 * reglas importa: primero se acepta el preflight de CORS, despues las rutas publicas y, por
 * ultimo, todo lo demas exige un token valido.</p>
 */
@RequiredArgsConstructor
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtFilter jwtFilter;
    private final CustomUserDetailsService userDetailsService;
    private final OAuth2SuccessHandler oAuth2SuccessHandler;

    /**
     * Construye la cadena de filtros que protege la API.
     *
     * @param http constructor de la configuracion de seguridad.
     * @return cadena de filtros ya construida.
     * @throws Exception si la configuracion de Spring Security no puede aplicarse.
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {

        return http.csrf(AbstractHttpConfigurer::disable)
                .cors(Customizer.withDefaults())
                .authorizeHttpRequests(req -> req
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()

                        .requestMatchers("/api/v1/flights/debug/**", "/api/v1/locations/debug/**").hasRole("ADMIN")

                        .requestMatchers("/oauth2/**", "/login/oauth2/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/v1/users/register", "/api/v1/users/login", "/api/v1/auth/google").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/users/verify").permitAll()

                        .requestMatchers(HttpMethod.GET, "/api/v1/locations/**", "/api/v1/flights/search", "/api/v1/flights/seats/search").permitAll()

                        .anyRequest().authenticated())
                .oauth2Login(oauth2 -> oauth2.successHandler(oAuth2SuccessHandler))
                .exceptionHandling(ex -> ex.authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    /**
     * Proporciona el proveedor de autenticacion por base de datos con BCrypt.
     *
     * @return proveedor configurado con un factor de coste de 12.
     */
    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userDetailsService);
        provider.setPasswordEncoder(new BCryptPasswordEncoder(12));

        return provider;
    }

    /**
     * Expone el gestor de autenticacion usado en el login.
     *
     * @param config configuracion de autenticacion de Spring Security.
     * @return gestor de autenticacion.
     * @throws Exception si no se puede obtener el gestor.
     */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}