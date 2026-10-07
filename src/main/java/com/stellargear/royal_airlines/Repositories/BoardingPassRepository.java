package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.BoardingPass;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.util.List;

/**
 * Acceso a la coleccion de pases de acudir.
 */
public interface BoardingPassRepository extends MongoRepository<BoardingPass, String> {

    /**
     * Busca un pase por su identificador.
     *
     * @param requestedID identificador del pase.
     * @return pase encontrado o {@code null}.
     */
    @Query("{ 'boardingPassID' : ?0 }")
    BoardingPass searchByID(String requestedID);

    /**
     * Lista todos los pases de un usuario.
     *
     * @param requestedID identificador del usuario.
     * @return pases del usuario, lista vacia si no tiene ninguno.
     */
    @Query("{ 'bookedUserID' : ?0 }")
    List<BoardingPass> searchListByUserID(String requestedID);

    /**
     * Lista los pases de un usuario filtrando por estado.
     *
     * @param requestedID identificador del usuario.
     * @param status nombre del estado, {@code ACTIVE} o {@code INACTIVE}.
     * @return pases del usuario en ese estado.
     */
    @Query("{ 'bookedUserID' : ?0, 'status' : ?1 }")
    List<BoardingPass> searchListByUserAndStatus(String requestedID, String status);
}