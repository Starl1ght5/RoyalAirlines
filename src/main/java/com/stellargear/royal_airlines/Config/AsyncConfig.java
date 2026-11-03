package com.stellargear.royal_airlines.Config;

import java.util.concurrent.ThreadPoolExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Define el pool de hilos que atiende el recalculo en caliente del recomendador Python.
 *
 * <p>{@code @Async} en {@code RecommenderClient} usa este ejecutor para no bloquear el hilo
 * de la peticion HTTP que guarda las preferencias: la respuesta sale al instante y el
 * recálculo ocurre en background con su propio timeout. La cola es corta y, si se llena,
 * la tarea se descarta con un log porque el job nocturno repara la lista igualmente.</p>
 */
@Configuration
public class AsyncConfig {

    private static final Logger logger = LoggerFactory.getLogger(AsyncConfig.class);

    /**
     * Crea el executor exclusivo del microservicio de recomendaciones.
     *
     * <p>Un solo hilo basta (Python atiende las peticiones de a una); el segundo aparece
     * solo cuando la cola ya esta llena, y a partir de ahi se descartan tareas.</p>
     *
     * @return executor con cola limitada y descarte silencioso salvo por el log de aviso.
     */
    @Bean("recommenderExecutor")
    public ThreadPoolTaskExecutor recommenderExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(2);
        executor.setQueueCapacity(20);
        executor.setThreadNamePrefix("recommender-");
        executor.setRejectedExecutionHandler(this::descartarPorSaturacion);
        executor.initialize();
        return executor;
    }

    /**
     * Descarta la tarea cuando la cola esta llena en vez de reventar el hilo llamador.
     *
     * @param tarea recalculo que no entra en la cola.
     * @param pool executor saturado.
     */
    private void descartarPorSaturacion(Runnable tarea, ThreadPoolExecutor pool) {
        logger.warn("Cola del recomendador llena: recalculo omitido; lo hara el proximo job");
    }
}
