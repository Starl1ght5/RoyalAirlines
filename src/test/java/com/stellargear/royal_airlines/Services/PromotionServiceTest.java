package com.stellargear.royal_airlines.Services;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.stellargear.royal_airlines.Models.Entities.Flight;
import com.stellargear.royal_airlines.Models.Entities.Location;
import com.stellargear.royal_airlines.Models.Entities.Promotion;
import com.stellargear.royal_airlines.Services.PromotionService.RouteStat;
import com.stellargear.royal_airlines.Utils.MoneyExchange;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.junit.jupiter.api.Test;

/**
 * Prueba la decision pura de las promociones (sin MongoDB): que el ranking mezcle descuento,
 * baratura, directo y featured; que respete el top-N y el tope por destino; que los textos
 * reflejen la ruta; y que el resumen de vuelos salga bien agrupado.
 */
class PromotionServiceTest {

    // ------------------------------------------------------------------
    // seleccion
    // ------------------------------------------------------------------

    @Test
    void seleccionaLasMejoresRutasPorPuntajeMixto() {
        // CTG gana por ser la mas barata + directa + featured (0.70); MDE queda segunda
        // con descuento pequeno pero buen precio (0.69); MAD es la mas cara y sin extras
        // (0.18) pese a su 30% de descuento.
        List<RouteStat> routes = List.of(
                route("BOG", "MAD", 900_000, 30, false, false),
                route("BOG", "CTG", 245_000, 0, true, true),
                route("BOG", "MDE", 400_000, 10, true, true));

        List<RouteStat> selected = PromotionService.select(routes);

        assertEquals(List.of("CTG", "MDE", "MAD"),
                selected.stream().map(RouteStat::destinationIata).toList());
    }

    @Test
    void soloUnaTarjetaPorCiudadDestino() {
        // Cuatro orígenes distintos hacia CTG: solo entra el mejor; MAD aprovecha el cupo
        // libre. Si no, el slider mostraria "Ofertas a Cartagena" repetido.
        List<RouteStat> routes = List.of(
                route("BOG", "CTG", 200_000, 0, true, true),
                route("MDE", "CTG", 210_000, 0, true, false),
                route("CLO", "CTG", 220_000, 0, true, false),
                route("CAL", "CTG", 230_000, 0, true, false),
                route("BOG", "MAD", 900_000, 15, false, false));

        List<RouteStat> selected = PromotionService.select(routes);

        long toCartagena = selected.stream()
                .filter(route -> route.destinationIata().equals("CTG"))
                .count();
        assertEquals(1, toCartagena);
        assertTrue(selected.stream().anyMatch(route -> route.destinationIata().equals("MAD")));
    }

    @Test
    void ciudadesEscritasDistintoSonLaMismaTarjeta() {
        // "Cartagena" y "cartagena " (misma ciudad, distinto texto) no deben sumar dos cupos.
        List<RouteStat> routes = List.of(
                new RouteStat("BOG", "CTG", "Bogotá", "Cartagena", 200_000, 1, 30, true, false,
                        ANCHOR_DATE),
                new RouteStat("MDE", "CTG", "Medellín", " cartagena ", 250_000, 1, 30, true, false,
                        ANCHOR_DATE));

        assertEquals(1, PromotionService.select(routes).size());
        assertEquals("cartagena",
                PromotionService.cityKey(" Cartagena "));
    }

    @Test
    void cortaEnElTopN() {
        List<RouteStat> routes = java.util.stream.IntStream.rangeClosed(1, 10)
                .mapToObj(index -> route("BOG", "D" + index, 300_000L + index, 0, true, false))
                .toList();

        assertEquals(PromotionService.TOP_N, PromotionService.select(routes).size());
    }

    @Test
    void sinVuelosLaSeleccionQuedaVacia() {
        assertTrue(PromotionService.select(List.of()).isEmpty());
    }

    // ------------------------------------------------------------------
    // textos de la tarjeta
    // ------------------------------------------------------------------

    @Test
    void unaRutaConDescuentoSePublicaComoOferta() {
        RouteStat route = route("BOG", "CTG", 500_000, 30, true, false);

        Promotion promotion = PromotionService.toPromotion(route, 1, true, true, Instant.now());

        assertEquals("promo_BOG_CTG", promotion.id());
        assertEquals("Ofertas a Cartagena", promotion.title());
        assertEquals("Vuelos directos desde Bogotá", promotion.subtitle());
        assertEquals("Hasta 30% OFF", promotion.discountLabel());
        assertEquals("BOG", promotion.origin());
        assertEquals("CTG", promotion.destination());
        // La fecha viaja en la tarjeta: al tocarla el front busca ese dia.
        assertEquals(ANCHOR_DATE, promotion.departureDate());
        assertTrue(promotion.active());
    }

    @Test
    void unaOfertaQueNoEsLaMejorConservaElTituloPeroMuestraElPrecio() {
        // todas tus rutas tienen 30%: el titulo sigue diciendo "Ofertas a ...", pero el badge
        // pone el precio para que seis tarjetas no repitan "Hasta 30% OFF".
        RouteStat route = route("BOG", "CTG", 245_000, 30, true, false);

        Promotion promotion = PromotionService.toPromotion(route, 1, false, true, Instant.now());

        assertEquals("Ofertas a Cartagena", promotion.title());
        assertEquals("Desde COP 245K", promotion.discountLabel());
    }

    @Test
    void elDescuentoEnElBadgeSeGanaSoloConLaMejorOferta() {
        List<RouteStat> selected = List.of(
                route("BOG", "MAD", 900_000, 20, false, false),
                route("BOG", "CTG", 245_000, 45, true, true),
                route("BOG", "MDE", 400_000, 30, true, false));

        RouteStat top = PromotionService.bestOffer(selected);

        assertEquals("CTG", top.destinationIata());
        // sin ningun descuento minimo no hay oferta que destacar
        assertNull(PromotionService.bestOffer(List.of(
                route("BOG", "MAD", 900_000, 0, false, false))));
    }

    @Test
    void unaRutaSinDescuentoSePublicaComoTarifaDesde() {
        RouteStat route = route("BOG", "MAD", 245_000, 0, false, false);

        Promotion promotion = PromotionService.toPromotion(route, 2, false, false, Instant.now());

        assertEquals("Madrid desde", promotion.title());
        assertEquals("Vuelos desde Bogotá", promotion.subtitle());
        assertEquals("Desde COP 245K", promotion.discountLabel());
        // Un active=false escrito a mano NO se pierde al refrescar.
        assertFalse(promotion.active());
        assertEquals(2, promotion.sortOrder());
    }

    @Test
    void formateaElPrecioEnCOPCorto() {
        assertEquals("245K", PromotionService.compactCop(245_000));
        assertEquals("89K", PromotionService.compactCop(89_000));
        assertEquals("1.2M", PromotionService.compactCop(1_200_000));
        assertEquals("1M", PromotionService.compactCop(1_000_000));
        assertEquals("950", PromotionService.compactCop(950));
    }

    // ------------------------------------------------------------------
    // resumen de vuelos
    // ------------------------------------------------------------------

    @Test
    void agrupaLosVuelosPorRutaYSeQuedaConLoMejor() {
        Map<String, Location> locations = Map.of(
                "id-bog", location("id-bog", "BOG", "Bogotá", false),
                "id-ctg", location("id-ctg", "CTG", "Cartagena", true));
        List<Flight> flights = List.of(
                flight("id-bog", "id-ctg", 60, 60, false, 0, 1),
                flight("id-bog", "id-ctg", 50, 60, true, 20, 0));

        List<RouteStat> routes = PromotionService.buildRouteStats(flights, locations,
                new MoneyExchange());

        assertEquals(1, routes.size());
        RouteStat route = routes.get(0);
        assertEquals("BOG", route.originIata());
        assertEquals("CTG", route.destinationIata());
        assertEquals("Bogotá", route.originCity());
        assertEquals("Cartagena", route.destinationCity());
        assertEquals(50 * 4000L, route.priceCop()); // el mas barato, ya en COP
        assertEquals(2, route.flightCount());
        assertEquals(20.0, route.maxDiscountPct(), 0.001);
        assertTrue(route.direct());
        assertTrue(route.featured());
    }

    @Test
    void ignoraLosVuelosSinPrecioSinFechaYSinDestinoEnElCatalogo() {
        Map<String, Location> locations = Map.of(
                "id-bog", location("id-bog", "BOG", "Bogotá", false),
                "id-ctg", location("id-ctg", "CTG", "Cartagena", true));
        List<Flight> unusable = List.of(
                flight("fantasma", "id-ctg", 40, 40, false, 0, 0),
                flight("id-bog", "fantasma", 40, 40, false, 0, 0),
                flight("id-bog", "id-ctg", 0, 0, false, 0, 0));
        Flight withoutDate = flight("id-bog", "id-ctg", 40, 40, false, 0, 0);
        withoutDate.setDepartureDate(null);

        List<RouteStat> routes = PromotionService.buildRouteStats(
                concat(unusable, withoutDate), locations, new MoneyExchange());

        assertTrue(routes.isEmpty());
    }

    @Test
    void laFechaDeLaTarjetaEsLaDelVueloMasBarato() {
        // La fecha es la del vuelo cuyo precio publica la tarjeta: si el mas barato sale
        // el 20, ese dia hay al menos un vuelo real que encontrar al tocar la promocion.
        Map<String, Location> locations = Map.of(
                "id-bog", location("id-bog", "BOG", "Bogotá", false),
                "id-ctg", location("id-ctg", "CTG", "Cartagena", true));
        Flight expensive = flight("id-bog", "id-ctg", 80, 80, false, 0, 0);
        expensive.setDepartureDate(LocalDateTime.of(2026, 11, 25, 8, 30));
        Flight cheap = flight("id-bog", "id-ctg", 50, 60, false, 0, 0);
        cheap.setDepartureDate(LocalDateTime.of(2026, 11, 20, 8, 30));

        List<RouteStat> routes = PromotionService.buildRouteStats(
                List.of(expensive, cheap), locations, new MoneyExchange());

        assertEquals(LocalDate.of(2026, 11, 20), routes.get(0).departureDate());
    }

    @Test
    void deduceElDescuentoDeLaBaseCuandoNoTraeLaBandera() {
        // hay vuelos con precio rebajado pero con discounted=false: el % sale de base vs ticket
        assertEquals(25.0, PromotionService.discountPercent(
                flight("a", "b", 75, 100, false, 0, 0)), 0.001);
        // con la bandera encendida manda discountPercentage
        assertEquals(20.0, PromotionService.discountPercent(
                flight("a", "b", 70, 100, true, 20, 0)), 0.001);
        // sin base ni bandera no hay descuento que contar
        assertEquals(0.0, PromotionService.discountPercent(
                flight("a", "b", 100, 100, false, 0, 0)), 0.001);
    }

    // ------------------------------------------------------------------
    // frescura de la coleccion
    // ------------------------------------------------------------------

    @Test
    void laColeccionEstaViejaSiEstaVaciaOSinMarcaDeGeneracion() {
        Instant now = Instant.now();
        Promotion fresh = promotion(now);
        Promotion old = promotion(now.minus(Duration.ofHours(7)));
        Promotion withoutMark = new Promotion("promo_001", "t", "s", "l", "BOG", "CTG",
                ANCHOR_DATE, true, 1, null);

        assertFalse(PromotionService.isStale(List.of(fresh)));
        assertTrue(PromotionService.isStale(List.of()));
        assertTrue(PromotionService.isStale(List.of(fresh, old)));
        assertTrue(PromotionService.isStale(List.of(withoutMark)));
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    /** Fecha fija del vuelo ancla en las tarjetas armadas a mano. */
    private static final LocalDate ANCHOR_DATE = LocalDate.of(2026, 11, 15);

    private static RouteStat route(String origin, String destination, long priceCop,
                                   double discountPct, boolean direct, boolean featured) {
        return new RouteStat(origin, destination, city(origin), city(destination), priceCop,
                1, discountPct, direct, featured, ANCHOR_DATE);
    }

    private static String city(String iata) {
        return switch (iata) {
            case "BOG" -> "Bogotá";
            case "CTG" -> "Cartagena";
            case "MDE" -> "Medellín";
            case "MAD" -> "Madrid";
            default -> iata;
        };
    }

    private static Promotion promotion(Instant generatedAt) {
        return new Promotion("promo_BOG_CTG", "t", "s", "l", "BOG", "CTG", ANCHOR_DATE,
                true, 1, generatedAt);
    }

    private static Location location(String id, String iata, String city, boolean featured) {
        Location location = new Location();
        location.setLocationID(id);
        location.setIataCode(iata);
        location.setCityName(city);
        location.setFeatured(featured);
        return location;
    }

    private static Flight flight(String originId, String destinationId, double price,
                                 double basePrice, boolean discounted, double discountPct,
                                 int scales) {
        Flight flight = new Flight();
        flight.setDepartureLocationID(originId);
        flight.setArrivalLocationID(destinationId);
        flight.setTicketPrice(price);
        flight.setBasePrice(basePrice);
        flight.setDiscounted(discounted);
        flight.setDiscountPercentage(discountPct);
        flight.setScales(scales);
        flight.setDepartureDate(LocalDateTime.now().plusDays(10));
        return flight;
    }

    private static List<Flight> concat(List<Flight> flights, Flight extra) {
        return java.util.stream.Stream.concat(flights.stream(), java.util.stream.Stream.of(extra))
                .filter(Objects::nonNull)
                .toList();
    }
}
