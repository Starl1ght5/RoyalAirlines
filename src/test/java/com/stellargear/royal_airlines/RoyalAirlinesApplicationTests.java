package com.stellargear.royal_airlines;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Prueba de arranque: verifica que el contexto de Spring carga sin errores.
 *
 * <p>Las propiedades en linea tienen prioridad sobre {@code application.properties} y sobre un
 * {@code .env} local, de modo que la prueba no depende de la maquina: sin Firebase, sin indices
 * y con valores ficticios para lo obligatorio. MongoDB se conecta de forma perezosa, asi que no
 * necesita estar levantado para que el contexto cargue.</p>
 */
@SpringBootTest(properties = {
        "spring.mongodb.uri=mongodb://localhost:27017",
        "spring.mongodb.database=royal_airlines_test",
        "spring.data.mongodb.auto-index-creation=false",
        "spring.security.oauth2.client.registration.google.client-id=test-client",
        "spring.security.oauth2.client.registration.google.client-secret=test-secret",
        "jwt.secret=dGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtMDEyMzQ1Njc4OQ==",
        "royal.internal-api-key=test-key",
        "royal.recommender-url=",
        "royal.push.enabled=false",
        "royal.push.firebase-credentials="
})
class RoyalAirlinesApplicationTests {

    @Test
    void contextLoads() {
    }
}
