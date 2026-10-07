package com.stellargear.royal_airlines.Services;

import com.stellargear.royal_airlines.Models.Entities.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Duration;
import java.util.Date;
import java.util.function.Function;

/**
 * Emite y valida los tokens JWT de la aplicacion.
 *
 * <p>El sujeto del token es el correo y el identificador del usuario viaja como claim propio, de
 * modo que el filtro de seguridad pueda autenticar sin volver a consultar el correo.</p>
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final Duration expiration;

    /**
     * Construye el servicio a partir de la configuracion.
     *
     * @param base64Secret clave HMAC en Base64.
     * @param expirationMinutes vigencia del token en minutos.
     * @throws IllegalStateException si la clave es demasiado corta para firma HS256.
     */
    public JwtService(@Value("${jwt.secret}") String base64Secret,
                      @Value("${jwt.expiration-minutes:30}") long expirationMinutes) {

        byte[] keyBytes = Decoders.BASE64.decode(base64Secret);

        if (keyBytes.length < 32) {
            throw new IllegalStateException("jwt.secret debe tener al menos 256 bits (32 bytes) en Base64");
        }

        this.key = Keys.hmacShaKeyFor(keyBytes);
        this.expiration = Duration.ofMinutes(expirationMinutes);
    }

    /**
     * Genera un token para el usuario indicado.
     *
     * @param user usuario autenticado.
     * @return token firmado con el correo como sujeto y su identificador como claim {@code id}.
     */
    public String generateToken(User user) {
        Date now = new Date();

        return Jwts.builder()
                .subject(user.getEmail())
                .claim("id", user.getUserID())
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expiration.toMillis()))
                .signWith(key)
                .compact();
    }

    /**
     * Extrae el correo del portador del token.
     *
     * @param token token firmado.
     * @return correo almacenado en el sujeto.
     */
    public String extractUserName(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    /**
     * Comprueba la firma, la vigencia y la pertenencia del token a un usuario.
     *
     * @param token token firmado.
     * @param userDetails usuario contra el que se valida.
     * @return {@code true} si el token es valido y no ha expirado.
     */
    public boolean validateToken(String token, UserDetails userDetails) {
        String userName = extractUserName(token);

        return userName.equals(userDetails.getUsername()) && !isTokenExpired(token);
    }

    /**
     * Indica si el token ya supero su fecha de expiracion.
     *
     * @param token token firmado.
     * @return {@code true} si el token esta vencido.
     */
    private boolean isTokenExpired(String token) {
        return extractClaim(token, Claims::getExpiration).before(new Date());
    }

    /**
     * Extrae un claim concreto del token.
     *
     * @param token token firmado.
     * @param claimResolver funcion que selecciona el claim buscado.
     * @param <T> tipo del claim.
     * @return valor del claim.
     */
    private <T> T extractClaim(String token, Function<Claims, T> claimResolver) {
        return claimResolver.apply(extractAllClaims(token));
    }

    /**
     * Verifica la firma del token y devuelve todos sus claims.
     *
     * @param token token firmado.
     * @return claims del token.
     */
    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}