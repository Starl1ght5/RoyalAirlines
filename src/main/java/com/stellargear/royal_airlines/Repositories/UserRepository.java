package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.User;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

/**
 * Acceso a la coleccion de usuarios.
 */
public interface UserRepository extends MongoRepository<User, String> {

    /**
     * Comprueba si el correo ya pertenece a una cuenta.
     *
     * @param requestedEmail correo a verificar.
     * @return usuario encontrado o {@code null} si el correo esta libre.
     */
    @Query("{ 'email' : ?0 }")
    User isEmailTaken(String requestedEmail);

    /**
     * Busca un usuario por su correo.
     *
     * @param requestedEmail correo del usuario.
     * @return usuario encontrado o {@code null}.
     */
    @Query("{ 'email' : ?0 }")
    User searchByEmail(String requestedEmail);

    /**
     * Busca un usuario por el identificador que Google le asigna.
     *
     * @param googleSub identificador estable de la cuenta en Google.
     * @return usuario encontrado o {@code null}.
     */
    User findByGoogleSub(String googleSub);

    /**
     * Busca un usuario por su codigo de verificacion de correo.
     *
     * @param token codigo recibido por correo.
     * @return usuario pendiente de verificar o {@code null}.
     */
    @Query("{ 'verificationCode' : ?0 }")
    User searchFromToken(String token);
}