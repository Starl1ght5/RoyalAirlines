package com.stellargear.royal_airlines.Config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Inicializa Firebase solo si {@code royal.push.enabled=true} y hay ruta de credenciales.
 * Si no, el bean no existe y {@code PushService} queda inactivo sin romper el arranque.
 */
@Configuration
@ConditionalOnExpression("${royal.push.enabled:false} and !'${royal.push.firebase-credentials:}'.isEmpty()")
public class FirebaseConfig {

  @Bean
  public FirebaseMessaging firebaseMessaging(
      @Value("${royal.push.firebase-credentials}") String credentialsPath) throws IOException {
    FirebaseApp app;
    if (FirebaseApp.getApps().isEmpty()) {
      Path path = Paths.get(credentialsPath);
      if (!Files.isReadable(path)) {
        throw new IllegalStateException(
            "No se puede leer el archivo de credenciales de Firebase en '" + credentialsPath
                + "'. Revisa FIREBASE_CREDENTIALS_PATH. En Windows usa '/' o '\\\\' "
                + "como separador (en .properties la barra invertida es un carácter de escape).");
      }
      try (InputStream credentials = Files.newInputStream(path)) {
        app = FirebaseApp.initializeApp(FirebaseOptions.builder()
            .setCredentials(GoogleCredentials.fromStream(credentials))
            .build());
      }
    } else {
      app = FirebaseApp.getInstance();
    }
    return FirebaseMessaging.getInstance(app);
  }
}
