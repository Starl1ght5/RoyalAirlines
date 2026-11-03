import 'package:royal_airlines/models/destination_profile.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';

/// DestinationCatalog
/// ------------------
/// Catálogo LOCAL de destinos con su perfil turístico, usado por el
/// motor de recomendaciones (Etapa C). Los pesos, meses y precios son
/// datos curados a mano — no vienen del backend, cuyo catálogo de
/// destinos solo expone código/ciudad/país/aeropuerto.
///
/// Dos grupos:
/// - RESERVABLES (`isBookable: true`): los destinos que ya existen en
///   el catálogo de vuelos de Home (BOG, MDE, CTG, CLO, MIA, MAD,
///   DOH). Al recomendarlos se puede saltar directo al buscador.
/// - ASPIRACIONALES (`isBookable: false`): ciudades que el profesor
///   usó de ejemplo en clase (Venecia, Marruecos, Moscú, Noruega) y
///   que hoy NO tienen ruta en la app. Se recomiendan como
///   inspiración; la tarjeta muestra "Próximamente" en vez de
///   "Reservar".
class DestinationCatalog {
  DestinationCatalog._();

  static const List<DestinationProfile> all = [
    // ------------------------------------------------------------------
    // Reservables (alineados con HomeRepository.getAirports)
    // ------------------------------------------------------------------
    DestinationProfile(
      code: 'CTG',
      city: 'Cartagena',
      country: 'Colombia',
      interestWeights: {
        TravelInterest.playa: 0.95,
        TravelInterest.gastronomia: 0.7,
        TravelInterest.descanso: 0.65,
        TravelInterest.cultura: 0.5,
        TravelInterest.ciudad: 0.4,
      },
      bestMonths: [12, 1, 2, 3],
      averagePriceCop: 320000,
    ),
    DestinationProfile(
      code: 'CLO',
      city: 'Cali',
      country: 'Colombia',
      interestWeights: {
        TravelInterest.gastronomia: 0.75,
        TravelInterest.aventura: 0.6,
        TravelInterest.cultura: 0.55,
        TravelInterest.ciudad: 0.45,
      },
      bestMonths: [6, 7, 8, 12],
      averagePriceCop: 280000,
    ),
    DestinationProfile(
      code: 'BOG',
      city: 'Bogotá',
      country: 'Colombia',
      interestWeights: {
        TravelInterest.cultura: 0.8,
        TravelInterest.ciudad: 0.8,
        TravelInterest.gastronomia: 0.7,
        TravelInterest.aventura: 0.45,
      },
      bestMonths: [3, 4, 5, 7],
      averagePriceCop: 190000,
    ),
    DestinationProfile(
      code: 'MDE',
      city: 'Medellín',
      country: 'Colombia',
      interestWeights: {
        TravelInterest.cultura: 0.7,
        TravelInterest.ciudad: 0.7,
        TravelInterest.gastronomia: 0.65,
        TravelInterest.descanso: 0.5,
      },
      bestMonths: [1, 2, 7, 8],
      averagePriceCop: 210000,
    ),
    DestinationProfile(
      code: 'MIA',
      city: 'Miami',
      country: 'Estados Unidos',
      interestWeights: {
        TravelInterest.playa: 0.8,
        TravelInterest.ciudad: 0.85,
        TravelInterest.gastronomia: 0.7,
        TravelInterest.descanso: 0.6,
      },
      bestMonths: [12, 1, 2, 3, 4],
      averagePriceCop: 1850000,
    ),
    DestinationProfile(
      code: 'MAD',
      city: 'Madrid',
      country: 'España',
      interestWeights: {
        TravelInterest.cultura: 0.95,
        TravelInterest.ciudad: 0.9,
        TravelInterest.gastronomia: 0.85,
        TravelInterest.descanso: 0.4,
      },
      bestMonths: [4, 5, 9, 10],
      averagePriceCop: 4200000,
    ),
    DestinationProfile(
      code: 'DOH',
      city: 'Doha',
      country: 'Qatar',
      interestWeights: {
        TravelInterest.ciudad: 0.85,
        TravelInterest.cultura: 0.75,
        TravelInterest.descanso: 0.6,
        TravelInterest.aventura: 0.5,
      },
      bestMonths: [11, 12, 1, 2, 3],
      averagePriceCop: 5100000,
    ),

    // ------------------------------------------------------------------
    // Aspiracionales (sin ruta todavía — inspiración de la clase)
    // ------------------------------------------------------------------
    DestinationProfile(
      code: 'VCE',
      city: 'Venecia',
      country: 'Italia',
      interestWeights: {
        TravelInterest.cultura: 0.95,
        TravelInterest.ciudad: 0.85,
        TravelInterest.descanso: 0.75,
        TravelInterest.gastronomia: 0.7,
      },
      bestMonths: [4, 5, 10, 11, 12],
      averagePriceCop: 5600000,
      isBookable: false,
    ),
    DestinationProfile(
      code: 'RAK',
      city: 'Marrakech',
      country: 'Marruecos',
      interestWeights: {
        TravelInterest.aventura: 0.9,
        TravelInterest.cultura: 0.85,
        TravelInterest.gastronomia: 0.75,
        TravelInterest.ciudad: 0.5,
      },
      bestMonths: [3, 4, 9, 10, 11],
      averagePriceCop: 4800000,
      isBookable: false,
    ),
    DestinationProfile(
      code: 'SVO',
      city: 'Moscú',
      country: 'Rusia',
      interestWeights: {
        TravelInterest.cultura: 0.85,
        TravelInterest.ciudad: 0.8,
        TravelInterest.nieve: 0.7,
      },
      bestMonths: [1, 2, 12],
      averagePriceCop: 6200000,
      isBookable: false,
    ),
    DestinationProfile(
      code: 'OSL',
      city: 'Oslo',
      country: 'Noruega',
      interestWeights: {
        TravelInterest.nieve: 0.95,
        TravelInterest.naturaleza: 0.9,
        TravelInterest.aventura: 0.75,
        TravelInterest.descanso: 0.4,
      },
      bestMonths: [11, 12, 1, 2, 3],
      averagePriceCop: 7100000,
      isBookable: false,
    ),
  ];

  /// Busca un destino por su código IATA; `null` si no existe.
  static DestinationProfile? byCode(String code) {
    for (final destination in all) {
      if (destination.code == code) return destination;
    }
    return null;
  }

  /// Busca un destino por nombre de ciudad, tolerando mayúsculas y
  /// acentos ausentes ("marruecos" matchea "Marruecos"). Útil para
  /// cruzar el `mostVisitedCity` del historial contra el catálogo.
  static DestinationProfile? byCity(String city) {
    final normalizedCity = _normalize(city);
    for (final destination in all) {
      if (_normalize(destination.city) == normalizedCity) {
        return destination;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .trim();
  }
}
