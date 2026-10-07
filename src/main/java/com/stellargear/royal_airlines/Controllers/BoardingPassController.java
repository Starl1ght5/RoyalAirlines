package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.BoardingPassDTO;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.BoardingPassService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Expone los pases de abordar del usuario autenticado.
 *
 * <p>Cada persona solo ve sus propios pases, identificados a partir del token. Un usuario sin
 * pases recibe una lista vacia con codigo 200, no un error.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/boarding")
public class BoardingPassController {

    private final BoardingPassService boardingPassService;

    /**
     * Lista todos los pases de abordar del usuario.
     *
     * @param principal usuario extraido del token JWT.
     * @return pases de abordar, vacios si el usuario no tiene ninguno.
     */
    @GetMapping(path = "/searchAll")
    public List<BoardingPassDTO> getAllBoardingPassesOfUser(@AuthenticationPrincipal UserPrincipal principal) {
        return boardingPassService.getAllBoardingPassesOfUser(principal.getUserID());
    }

    /**
     * Lista los pases de abordar vigentes del usuario.
     *
     * @param principal usuario extraido del token JWT.
     * @return pases con estado activo.
     */
    @GetMapping(path = "/searchActive")
    public List<BoardingPassDTO> getAllActiveBoardingPassesOfUser(@AuthenticationPrincipal UserPrincipal principal) {
        return boardingPassService.getAllActiveBoardingPassesOfUser(principal.getUserID());
    }

    /**
     * Lista los pases de aboardar ya inutilizados del usuario.
     *
     * @param principal usuario extraido del token JWT.
     * @return pases con estado inactivo.
     */
    @GetMapping(path = "/searchInactive")
    public List<BoardingPassDTO> getAllInactiveBoardingPassesOfUser(@AuthenticationPrincipal UserPrincipal principal) {
        return boardingPassService.getAllInactiveBoardingPassesOfUser(principal.getUserID());
    }
}