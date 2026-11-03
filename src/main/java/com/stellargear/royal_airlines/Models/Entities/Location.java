package com.stellargear.royal_airlines.Models.Entities;

import com.stellargear.royal_airlines.Models.Enums.ClimateType;
import com.stellargear.royal_airlines.Models.Enums.LocationStatus;
import com.stellargear.royal_airlines.Models.Enums.VisaPolicy;
import lombok.Getter;
import lombok.Setter;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Destino turistico servido por la aerolinea.
 *
 * <p>Los destinos marcados como secretos quedan ocultos del catalogo publico y solo se usan
 * desde las operaciones internas de la aplicacion.</p>
 *
 * <p>Las propiedades turisticas se guardan de forma estructurada (etiquetas con peso, meses como
 * numeros, clima normalizado) para que el servicio de recomendaciones pueda compararlas con el
 * perfil del usuario sin interpretar texto libre.</p>
 */
@Setter
@Getter
@Document(collection = "Destinations")
public class Location {

    /** Version del esquema con que se escribio el documento; 0 o ausente indica documento antiguo. */
    public static final int CURRENT_SCHEMA_VERSION = 3;

    @Id
    private String locationID;
    private String cityName;
    private String countryName;
    private String iataCode;
    private String airportName;
    private LocationStatus status;
    private double rating;
    private boolean featured;

    /**
     * Etiquetas turisticas con peso de 0.0 a 1.0, por ejemplo {"playa": 0.95, "gastronomia": 0.7}.
     *
     * <p>Usar un vocabulario controlado en minusculas y sin puntos: MongoDB no admite puntos en
     * las llaves de un mapa.</p>
     */
    private Map<String, Double> tags;

    /**
     * Encaje del destino con cada tipo de viajero, con peso de 0.0 a 1.0, por ejemplo
     * {"solo": 0.6, "pareja": 0.9}. Se cruza con {@code Booking.companionType}.
     */
    private Map<String, Double> travelerFit;

    /** Meses recomendados para viajar, del 1 al 12. */
    private List<Integer> bestMonths;

    /** Clima normalizado del destino. */
    private ClimateType climateType;

    /** Nivel de costo de vida del destino, de 1 (economico) a 4 (muy costoso). */
    private int costLevel;

    /** Requisitos de visa del destino para pasaporte colombiano. */
    private VisaPolicy visaPolicy;

    /** Aviso al usuario sobre el control de entrada, por ejemplo el ETIAS pendiente. */
    private String entryNote;

    /** Numero de calificaciones recibidas; el modelo ignora {@code rating} mientras sea 0. */
    private int ratingCount;

    /** Imagen del destino para las tarjetas del front. */
    private String imageUrl;

    /** Version del esquema con que se guardo este documento. */
    private int schemaVersion;

    /** Fecha de la ultima modificacion del documento. */
    private LocalDateTime updatedAt;

    /**
     * Precio mas bajo disponible hacia este destino.
     *
     * <p>Ya no se guarda en la base: el servicio lo calcula a partir de los vuelos vigentes (y mas
     * adelante del historial de precios) antes de devolver el destino.</p>
     */
    private double cheapestPrice;

    /** Crea el destino vacio para que el servicio asigne sus campos. */
    public Location() {}
}