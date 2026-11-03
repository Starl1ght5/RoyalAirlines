package com.stellargear.royal_airlines.Services;

import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Cliente del microservicio Python (recomendador), para recalcular en caliente las listas
 * cuando cambian las preferencias del usuario.
 *
 * <p>Flujo: el usuario guarda sus preferencias, Spring borra su {@code UserRecommendations}
 * (invalidación) y llama a {@code POST /recomendaciones/{id}} con la misma
 * {@code INTERNAL_API_KEY}. La llamada corre en background (executor {@code recommenderExecutor},
 * ver {@link com.stellargear.royal_airlines.Config.AsyncConfig}) con timeout de 10 s, así que
 * guardar preferencias no espera a Python. Si el microservicio no responde a tiempo, el error
 * se traga con un log: la app sigue funcionando con {@code __popular__} y el job
 * nocturno repara la lista.</p>
 *
 * <p>Sin {@code royal.recommender-url} el cliente queda deshabilitado y solo ocurre la
 * invalidación: las preferencias nuevas se aplican en la siguiente ejecución del job.</p>
 */
@Component
public class RecommenderClient {

    private static final Logger logger = LoggerFactory.getLogger(RecommenderClient.class);
    private static final Duration TIMEOUT = Duration.ofSeconds(10);

    private final RestClient client;
    private final String apiKey;

    /**
     * Construye el cliente apuntando a la URL del microservicio.
     *
     * @param baseUrl URL base del recomendador (p. ej. http://localhost:8001); vacía = deshabilitado.
     * @param apiKey clave interna compartida con el microservicio.
     */
    public RecommenderClient(@Value("${royal.recommender-url:}") String baseUrl,
                             @Value("${royal.internal-api-key:}") String apiKey) {
        this.apiKey = apiKey == null ? "" : apiKey;
        this.client = (baseUrl == null || baseUrl.isBlank()) ? null : RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(requestFactory())
                .build();
    }

    /**
     * Indica si el recálculo en caliente está disponible (URL y clave configuradas).
     *
     * @return {@code true} si se puede llamar al microservicio.
     */
    public boolean isEnabled() {
        return client != null && !apiKey.isBlank();
    }

    /**
     * Pide al microservicio que recalcule y guarde la lista de un usuario con sus
     * preferencias actuales. Nunca propaga errores: la app no depende de Python.
     *
     * <p>Se ejecuta en el executor {@code recommenderExecutor}: quien llama recibe el control
     * de inmediato y el POST ocurre en un hilo aparte.</p>
     *
     * @param userID usuario cuyas preferencias cambiaron.
     */
    @Async("recommenderExecutor")
    public void recalcularUsuario(String userID) {
        if (!isEnabled()) {
            logger.debug("Recomendador no configurado: solo invalidación, el job recalcula");
            return;
        }

        try {
            client.post()
                    .uri("/recomendaciones/{id}", userID)
                    .header("X-API-Key", apiKey)
                    .retrieve()
                    .toBodilessEntity();
            logger.info("Recomendaciones de {} recalculadas en caliente", userID);
        } catch (Exception error) {
            logger.warn("No se pudo recalcular en caliente para {} ({}); hasta el próximo job "
                    + "se servirá __popular__", userID, error.getMessage());
        }
    }

    private static ClientHttpRequestFactory requestFactory() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(TIMEOUT);
        factory.setReadTimeout(TIMEOUT);
        return factory;
    }
}
