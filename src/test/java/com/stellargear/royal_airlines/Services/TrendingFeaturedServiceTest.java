package com.stellargear.royal_airlines.Services;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import com.stellargear.royal_airlines.Services.TrendingFeaturedService.TrendingCount;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * Prueba de la decision pura del featured dinamico (sin MongoDB): que el ranking salga por
 * usuarios unicos, que se corte en el top-N, que respete el minimo de muestra y que solo
 * destinos ACTIVE puedan quedar destacados.
 */
class TrendingFeaturedServiceTest {

    private static Location location(String id, LocationStatus status) {
        Location location = new Location();
        location.setLocationID(id);
        location.setStatus(status);
        return location;
    }

    /**
     * Lista que entrega el refresh: SOLO destinos ACTIVE (el repository lo filtra con
     * findByStatus(ACTIVE)); selectFeatured confia en este parametro y no vuelve a mirar
     * el estado, por eso un HIDDEN jamas debe venir aqui.
     */
    private static final List<Location> ACTIVES = List.of(
            location("ctg", LocationStatus.ACTIVE),
            location("mad", LocationStatus.ACTIVE),
            location("mia", LocationStatus.ACTIVE),
            location("bog", LocationStatus.ACTIVE),
            location("clo", LocationStatus.ACTIVE),
            location("mde", LocationStatus.ACTIVE));

    @Test
    void ordenaPorUsuariosUnicosYCortaEnElTopN() {
        List<TrendingCount> counts = List.of(
                new TrendingCount("clo", 4),
                new TrendingCount("ctg", 12),
                new TrendingCount("mad", 9),
                new TrendingCount("mia", 7),
                new TrendingCount("bog", 5),
                new TrendingCount("mde", 3));

        Set<String> featured = TrendingFeaturedService.selectFeatured(counts, ACTIVES);

        // TOP_N = 5: el sexto (mde, con el minimo justito) queda fuera, pero el orden
        // dentro del top es por usuarios unicos.
        assertEquals(List.of("ctg", "mad", "mia", "bog", "clo"), List.copyOf(featured));
    }

    @Test
    void excluyeDestinosSinElMinimoDeUsuariosUnicos() {
        List<TrendingCount> counts = List.of(
                new TrendingCount("ctg", 10),
                new TrendingCount("mad", 2), // ruido: debajo de MIN_UNIQUE_VIEWERS
                new TrendingCount("mia", 0));

        Set<String> featured = TrendingFeaturedService.selectFeatured(counts, ACTIVES);

        assertEquals(Set.of("ctg"), featured);
    }

    @Test
    void soloLosDestinosActivePuedenQuedarDestacados() {
        // ven es HIDDEN (por eso NO esta en ACTIVES) y fantasma no existe como Location:
        // ninguno de los dos puede quedar featured aunque tengan mas vistas que ctg.
        List<TrendingCount> counts = List.of(
                new TrendingCount("ven", 50),
                new TrendingCount("ctg", 8),
                new TrendingCount("fantasma", 30));

        Set<String> featured = TrendingFeaturedService.selectFeatured(counts, ACTIVES);

        assertEquals(Set.of("ctg"), featured);
    }

    @Test
    void empatanPorIdParaQueElRankingSeaEstable() {
        List<TrendingCount> counts = List.of(
                new TrendingCount("mde", 6),
                new TrendingCount("mia", 6),
                new TrendingCount("bog", 6));

        Set<String> featured = TrendingFeaturedService.selectFeatured(counts, ACTIVES);

        assertEquals(List.of("bog", "mde", "mia"), List.copyOf(featured));
    }

    @Test
    void sinSenalLaDecisionQuedaVaciaYElRefreshNoTocaElCatalogo() {
        // Counts vacios (semana seca / sin consentimientos): selectFeatured devuelve vacio
        // y refresh() usa eso para conservar el featured anterior en vez de vaciar Home.
        assertTrue(TrendingFeaturedService.selectFeatured(List.of(), ACTIVES).isEmpty());
    }
}
