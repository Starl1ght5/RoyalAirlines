package com.stellargear.royal_airlines.Repositories;

import com.stellargear.royal_airlines.Models.Entities.Promotion;
import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;

/**
 * Acceso a la coleccion de promociones del slider de Home.
 */
public interface PromotionRepository extends MongoRepository<Promotion, String> {

    /**
     * Lista las promociones visibles en el orden en que deben mostrarse.
     *
     * @return promociones con {@code active=true}, ordenadas por {@code sortOrder}.
     */
    List<Promotion> findByActiveTrueOrderBySortOrderAsc();
}
