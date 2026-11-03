package com.stellargear.royal_airlines.Services;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.stellargear.royal_airlines.Models.DTOs.ChangePasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.ForgotPasswordRequest;
import com.stellargear.royal_airlines.Models.DTOs.ResetPasswordRequest;
import com.stellargear.royal_airlines.Models.Entities.User;
import com.stellargear.royal_airlines.Repositories.UserRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.server.ResponseStatusException;

/**
 * Prueba el cambio de contrasena y la solicitud de recuperacion sin levantar MongoDB.
 *
 * <p>Se usa el mismo BCrypt de 12 rondas que el servicio, de modo que lo comprobado sea el hash
 * real y no un doble.</p>
 */
@ExtendWith(MockitoExtension.class)
class UserServicePasswordTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private JwtService jwtService;

    @Mock
    private AuthenticationManager authenticationManager;

    @InjectMocks
    private UserService userService;

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);

    @Test
    void changePasswordRechazaUnaContrasenaActualIncorrecta() {
        User user = userWithPassword("actual123");
        when(userRepository.findById("u1")).thenReturn(Optional.of(user));

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> userService.changePassword("u1", new ChangePasswordRequest("equivocada", "nueva12345")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        assertEquals("La contrasena actual no es correcta", error.getReason());
        verify(userRepository, never()).save(any());
    }

    @Test
    void changePasswordGuardaElHashNuevoYLimpiaElCodigoDeRecuperacion() {
        User user = userWithPassword("actual123");
        user.setPasswordResetCode("123456");
        user.setPasswordResetExpiresAt(LocalDateTime.now().plusMinutes(20));
        when(userRepository.findById("u1")).thenReturn(Optional.of(user));

        userService.changePassword("u1", new ChangePasswordRequest("actual123", "nueva12345"));

        assertTrue(new BCryptPasswordEncoder().matches("nueva12345", user.getPassword()));
        assertNull(user.getPasswordResetCode());
        assertNull(user.getPasswordResetExpiresAt());
        verify(userRepository).save(user);
    }

    @Test
    void changePasswordRechazaUnaCuentaCreadaConGoogle() {
        User user = userWithPassword(null);
        when(userRepository.findById("u1")).thenReturn(Optional.of(user));

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> userService.changePassword("u1", new ChangePasswordRequest("actual123", "nueva12345")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        assertTrue(error.getReason().contains("Google/Apple"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void forgotPasswordNoRevelaSiElCorreoNoExiste() {
        when(userRepository.searchByEmail("nadie@test.com")).thenReturn(null);

        userService.requestPasswordReset(new ForgotPasswordRequest("nadie@test.com"));

        verify(userRepository, never()).save(any());
    }

    @Test
    void forgotPasswordGuardaUnCodigoDeSeisDigitosConVencimiento() {
        User user = userWithPassword("actual123");
        when(userRepository.searchByEmail("viajero@test.com")).thenReturn(user);

        LocalDateTime antes = LocalDateTime.now();
        userService.requestPasswordReset(new ForgotPasswordRequest("viajero@test.com"));

        assertTrue(user.getPasswordResetCode().matches("\\d{6}"));
        assertTrue(user.getPasswordResetExpiresAt().isAfter(antes.plusMinutes(29)));
        verify(userRepository).save(user);
    }

    @Test
    void resetPasswordGuardaLaNuevaContrasenaYConsumeElCodigo() {
        User user = userWithResetCode("123456", LocalDateTime.now().plusMinutes(10));
        when(userRepository.searchByEmail("viajero@test.com")).thenReturn(user);

        userService.resetPassword(new ResetPasswordRequest("viajero@test.com", "123456", "nueva12345"));

        assertTrue(new BCryptPasswordEncoder().matches("nueva12345", user.getPassword()));
        assertNull(user.getPasswordResetCode());
        assertNull(user.getPasswordResetExpiresAt());
        verify(userRepository).save(user);
    }

    @Test
    void resetPasswordRechazaUnCodigoEquivocado() {
        User user = userWithResetCode("123456", LocalDateTime.now().plusMinutes(10));
        when(userRepository.searchByEmail("viajero@test.com")).thenReturn(user);

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> userService.resetPassword(
                        new ResetPasswordRequest("viajero@test.com", "654321", "nueva12345")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        assertEquals("El codigo es invalido o ha expirado", error.getReason());
        verify(userRepository, never()).save(any());
    }

    @Test
    void resetPasswordRechazaUnCodigoVencido() {
        User user = userWithResetCode("123456", LocalDateTime.now().minusMinutes(1));
        when(userRepository.searchByEmail("viajero@test.com")).thenReturn(user);

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> userService.resetPassword(
                        new ResetPasswordRequest("viajero@test.com", "123456", "nueva12345")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatusCode());
        verify(userRepository, never()).save(any());
    }

    @Test
    void resetPasswordNoRevelaSiElCorreoNoExiste() {
        when(userRepository.searchByEmail("nadie@test.com")).thenReturn(null);

        ResponseStatusException error = assertThrows(ResponseStatusException.class,
                () -> userService.resetPassword(
                        new ResetPasswordRequest("nadie@test.com", "123456", "nueva12345")));

        // Mismo mensaje que un codigo equivocado: no se puede enumerar cuentas.
        assertEquals("El codigo es invalido o ha expirado", error.getReason());
        verify(userRepository, never()).save(any());
    }

    private User userWithResetCode(String code, LocalDateTime expiresAt) {
        User user = userWithPassword("actual123");
        user.setPasswordResetCode(code);
        user.setPasswordResetExpiresAt(expiresAt);
        return user;
    }

    private User userWithPassword(String plainPassword) {
        User user = new User();
        user.setUserID("u1");
        user.setEmail("viajero@test.com");
        user.setPassword(plainPassword == null ? null : encoder.encode(plainPassword));
        return user;
    }
}
