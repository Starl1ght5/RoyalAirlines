package com.stellargear.royal_airlines.Services;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;

/**
 * Envoltorio de FCM. Nunca lanza excepciones hacia afuera: un fallo de push no debe romper la
 * creacion de un vuelo ni el flujo que lo llamo. Sin credenciales configuradas queda inactivo
 * ({@link #isEnabled()} en false).
 */
@Service
@RequiredArgsConstructor
public class PushService {

  private static final Logger logger = LoggerFactory.getLogger(PushService.class);

  /** Canal de Android que la app Flutter debe crear con este mismo id. */
  static final String ANDROID_CHANNEL = "offers";

  private final ObjectProvider<FirebaseMessaging> messagingProvider;
  private final DeviceTokenService deviceTokenService;

  public boolean isEnabled() {
    return messagingProvider.getIfAvailable() != null;
  }

  /**
   * Envia una notificacion a todos los dispositivos del usuario.
   *
   * @param userId destinatario.
   * @param title titulo visible.
   * @param body cuerpo visible.
   * @param data pares clave/valor (solo cadenas) que la app lee al tocar la notificacion.
   * @return cantidad de dispositivos a los que FCM entrego el mensaje (0 si no hay ninguno).
   */
  public int send(String userId, String title, String body, Map<String, String> data) {
    return send(userId, deviceTokenService.tokensOf(userId), title, body, data);
  }

  /** Igual que {@link #send(String, String, String, Map)} con los tokens ya consultados. */
  public int send(String userId, List<String> tokens, String title, String body,
                  Map<String, String> data) {
    FirebaseMessaging messaging = messagingProvider.getIfAvailable();
    if (messaging == null || tokens == null || tokens.isEmpty()) {
      return 0;
    }

    try {
      MulticastMessage message = MulticastMessage.builder()
          .addAllTokens(tokens)
          .setNotification(Notification.builder().setTitle(title).setBody(body).build())
          .putAllData(data)
          .setAndroidConfig(AndroidConfig.builder()
              .setPriority(AndroidConfig.Priority.HIGH)
              .setNotification(AndroidNotification.builder().setChannelId(ANDROID_CHANNEL).build())
              .build())
          .build();

      BatchResponse response = messaging.sendEachForMulticast(message);
      removeDeadTokens(tokens, response);
      logger.info("Push a usuario {}: {} entregados, {} fallidos",
          userId, response.getSuccessCount(), response.getFailureCount());
      return response.getSuccessCount();
    } catch (FirebaseMessagingException | RuntimeException error) {
      logger.warn("No se pudo enviar el push al usuario {}: {}", userId, error.getMessage());
      return 0;
    }
  }

  /** Borra los tokens que FCM marca como desinstalados o invalidos. */
  private void removeDeadTokens(List<String> tokens, BatchResponse response) {
    List<String> dead = new ArrayList<>();
    List<SendResponse> results = response.getResponses();

    for (int i = 0; i < results.size(); i++) {
      SendResponse result = results.get(i);
      if (result.isSuccessful() || result.getException() == null) {
        continue;
      }
      MessagingErrorCode code = result.getException().getMessagingErrorCode();
      if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
        dead.add(tokens.get(i));
      }
    }
    deviceTokenService.removeTokens(dead);
  }
}
