package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.RecommendationListDTO;
import com.stellargear.royal_airlines.Models.Utils.UserPrincipal;
import com.stellargear.royal_airlines.Services.RecommendationService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.annotation.AuthenticationPrincipal;

/**
 * Expone las recomendaciones precalculadas por el microservicio Python.
 *
 * <p>La app nunca espera a Python: si el job no corrio, el servicio responde con el respaldo
 * de populares y ofertas en vez de fallar.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/recommendations")
public class RecommendationController {

    private final RecommendationService recommendationService;

    /**
     * Lista de destinos recomendados para el usuario autenticado.
     *
     * @param principal usuario extraido del token JWT.
     * @return lista propia, la general {@code __popular__} o el respaldo.
     */
    @GetMapping
    public RecommendationListDTO getRecommendations(@AuthenticationPrincipal UserPrincipal principal) {
        return recommendationService.forUser(principal.getUserID());
    }
}