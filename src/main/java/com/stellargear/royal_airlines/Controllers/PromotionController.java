package com.stellargear.royal_airlines.Controllers;

import com.stellargear.royal_airlines.Models.DTOs.PromotionDTO;
import com.stellargear.royal_airlines.Services.PromotionService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expone las promociones del slider de Home.
 *
 * <p>Ruta publica (ver SecurityConfig): el front la pide sin token y el error de cualquier otro
 * endpoint no debe impedir que el slider se cargue.</p>
 */
@RestController
@RequiredArgsConstructor
@RequestMapping(path = "/api/v1/promotions")
public class PromotionController {

    private final PromotionService promotionService;

    /**
     * Lista las promociones activas.
     *
     * <p>Responde con un ARRAY suelto (no paginado y sin envoltorio): el cliente de Flutter
     * envuelve la lista en {@code data} y a partir de ahi el slider la pinta.</p>
     *
     * @return promociones activas en orden de mostrado.
     */
    @GetMapping
    public List<PromotionDTO> getPromotions() {
        return promotionService.getActivePromotions();
    }
}
