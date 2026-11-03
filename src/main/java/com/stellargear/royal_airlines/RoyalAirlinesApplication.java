package com.stellargear.royal_airlines;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.web.config.EnableSpringDataWebSupport;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Punto de entrada de la aplicacion Royal Airlines.
 *
 * <p>Activa el soporte de paginacion de Spring Data con serializacion mediante DTO, para que
 * las entidades de MongoDB nunca se expongan directamente en las respuestas; habilita las
 * tareas programadas que expiran las reservas pendientes y refrescan el precio minimo de los
 * destinos; y habilita las llamadas asincronas, hoy usadas por el recalculario en caliente
 * del recomendador para no frenar al usuario que guarda sus preferencias.</p>
 */
@EnableSpringDataWebSupport(pageSerializationMode = EnableSpringDataWebSupport.PageSerializationMode.VIA_DTO)
@EnableScheduling
@EnableAsync
@SpringBootApplication
public class RoyalAirlinesApplication {

    /**
     * Levanta el contexto de la aplicacion.
     *
     * @param args argumentos de linea de comandos que Spring Boot utiliza para configurar el entorno.
     */
    public static void main(String[] args) {
        SpringApplication.run(RoyalAirlinesApplication.class, args);
    }
}