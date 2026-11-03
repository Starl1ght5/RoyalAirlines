import 'package:royal_airlines/models/travel_class.dart';

/// TravelInterest
/// --------------
/// Tipos de viaje que al usuario le interesan (playa, cultura,
/// naturaleza...). Es el principal insumo del futuro motor de
/// recomendaciones (Etapa C) para casar intereses con categorías de
/// destinos.
///
/// NOTA DE NOMBRE: se llama [TravelInterest] y NO `TripType` porque ya
/// existe un enum `TripType` (Ida y vuelta / Solo ida) en
/// `features/home/controller/home_controller.dart`; reutilizar ese
/// nombre generaría confusión entre dos conceptos distintos.
enum TravelInterest {
  aventura('Aventura'),
  cultura('Cultura'),
  playa('Playa'),
  naturaleza('Naturaleza'),
  gastronomia('Gastronomía'),
  descanso('Descanso'),
  ciudad('Ciudad'),
  nieve('Nieve y auroras');

  const TravelInterest(this.label);

  /// Texto en español para mostrar en la UI.
  final String label;

  static TravelInterest? tryParse(String? value) {
    for (final interest in values) {
      if (interest.name == value) return interest;
    }
    return null;
  }
}

/// TravelStyle
/// -----------
/// Estilo general de viaje del usuario (refinamiento opcional del
/// perfil). No es obligatorio para recibir recomendaciones.
enum TravelStyle {
  economico('Económico'),
  equilibrado('Equilibrado'),
  comodo('Cómodo'),
  premium('Premium');

  const TravelStyle(this.label);

  final String label;

  static TravelStyle? tryParse(String? value) {
    for (final style in values) {
      if (style.name == value) return style;
    }
    return null;
  }
}

/// TravelCompany
/// -------------
/// Con quién suele viajar el usuario (señal declarada de la Etapa B).
/// Los valores coinciden EXACTAMENTE con el vocabulario que acepta el
/// backend (`solo` | `pareja` | `familia` | `amigos`): el `name` del
/// enum es la clave que viaja en el JSON.
enum TravelCompany {
  solo('Solo'),
  pareja('En pareja'),
  familia('En familia'),
  amigos('Con amigos');

  const TravelCompany(this.label);

  /// Texto en español para mostrar en la UI.
  final String label;

  static TravelCompany? tryParse(String? value) {
    for (final company in values) {
      if (company.name == value) return company;
    }
    return null;
  }
}

/// TravelerPreferencesModel
/// ------------------------
/// Preferencias de viaje DECLARADAS por el usuario (inputs que él
/// mismo ingresa). Es un modelo independiente, a propósito:
///
/// - NO es [UserModel] (cuenta/seguridad: nombre, correo, contraseña).
/// - NO es [TravelerProfileModel] (resultado analítico que se
///   recalcula solo a partir del historial de reservas; no se persiste
///   y se borra lógicamente sin reservas).
///
/// Este modelo sí se persiste por usuario (ver
/// `TravelerPreferencesStorage`, clave `traveler_prefs_<userId>`) y
/// sobrevive a cerrar sesión, igual que el historial de reservas.
///
/// Distingue dos estados:
/// - DATOS INVÁLidos: violan una regla (presupuesto invertido, meses
///   fuera de rango, sin intereses) → bloquean el guardado.
/// - DATOS INCOMPLETOS: faltan campos opcionales/recomendados (meses,
///   estilo, clase) → se permiten guardar y se muestran como
///   sugerencias, nunca como errores.
class TravelerPreferencesModel {
  /// Tipos de viaje de interés. Obligatorio: al menos uno para poder
  /// guardar.
  final List<TravelInterest> interests;

  /// Presupuesto mínimo estimado por viaje, en COP. Debe ser >= 0.
  final double budgetMin;

  /// Presupuesto máximo estimado por viaje, en COP. Debe ser >= 0 y
  /// >= [budgetMax]... es decir, `budgetMax >= budgetMin`.
  final double budgetMax;

  /// Meses del año (1-12) en los que el usuario puede viajar.
  /// Recomendado, no obligatorio.
  final List<int> preferredMonths;

  /// Estilo de viaje general. Totalmente opcional.
  final TravelStyle? style;

  /// Clase de vuelo preferida. Totalmente opcional. Reutiliza el enum
  /// existente [TravelClass] (no se duplica).
  final TravelClass? preferredClass;

  // ------------------------------------------------------------------
  // Campos ampliados (Etapa B): las señales más valiosas para el
  // recomendador. Todos OPCIONALES: el backend solo exige `interests`
  // y `budgetMax`, y un usuario que nunca los tocó debe poder seguir
  // guardando lo básico sin arrastrar huecos obligatorios.
  // ------------------------------------------------------------------

  /// Con quién viaja normalmente. `null` = no declarado.
  final TravelCompany? travelCompany;

  /// Duración mínima del viaje en días (1-90). `null` = no declarado.
  final int? tripDaysMin;

  /// Duración máxima del viaje en días (1-90). `null` = no declarado.
  final int? tripDaysMax;

  /// Cuántos días de flexibilidad acepta para mover las fechas
  /// (0-30). `null` = no declarado.
  final int? flexibilityDays;

  /// Aeropuerto de origen habitual, código IATA de 3 letras (`BOG`).
  /// `null` = no declarado.
  final String? homeAirportCode;

  /// `true` si quiere ver solo vuelos directos, `false` si acepta
  /// escalas y `null` si nunca tocó el switch.
  final bool? directFlightsOnly;

  /// `Location.locationID` de destinos que NO quiere ver en las
  /// recomendaciones (hasta 100). Vacío = sin exclusiones.
  final List<String> excludedLocationIds;

  /// Límites del contrato del backend (`PUT /users/me/preferences`).
  /// Están aquí para que la UI y la validación usen SIEMPRE los
  /// mismos números que el servidor.
  static const int tripDaysMinLimit = 1;
  static const int tripDaysMaxLimit = 90;
  static const int flexibilityDaysLimit = 30;
  static const int excludedLocationsLimit = 100;

  const TravelerPreferencesModel({
    this.interests = const [],
    this.budgetMin = 0,
    this.budgetMax = 0,
    this.preferredMonths = const [],
    this.style,
    this.preferredClass,
    this.travelCompany,
    this.tripDaysMin,
    this.tripDaysMax,
    this.flexibilityDays,
    this.homeAirportCode,
    this.directFlightsOnly,
    this.excludedLocationIds = const [],
  });

  factory TravelerPreferencesModel.empty() => const TravelerPreferencesModel();

  /// Preferencias "sin datos": ningún campo aporta información.
  bool get hasPreferences =>
      interests.isNotEmpty ||
      budgetMax > 0 ||
      preferredMonths.isNotEmpty ||
      style != null ||
      preferredClass != null ||
      travelCompany != null ||
      tripDaysMin != null ||
      tripDaysMax != null ||
      flexibilityDays != null ||
      homeAirportCode != null ||
      directFlightsOnly != null ||
      excludedLocationIds.isNotEmpty;

  /// Igualdad PROFUNDA entre dos preferencias: `true` si todas las
  /// propiedades del perfil son equivalentes. Es la señal que usa
  /// [TravelerPreferencesController.save] para NO disparar el
  /// `PUT /users/me/preferences` cuando el usuario guarda sin tocar
  /// nada: ese PUT invalida y recalcula las recomendaciones en el
  /// backend, así que un guardado sin cambios no debe provocar refresh.
  ///
  /// Los campos de lista (intereses, meses y destinos excluidos) se
  /// comparan como CONJUNTOS: el orden en que el usuario los marcó no
  /// es un cambio de perfil.
  bool sameAs(TravelerPreferencesModel other) {
    if (identical(this, other)) return true;
    return budgetMin == other.budgetMin &&
        budgetMax == other.budgetMax &&
        style == other.style &&
        preferredClass == other.preferredClass &&
        travelCompany == other.travelCompany &&
        tripDaysMin == other.tripDaysMin &&
        tripDaysMax == other.tripDaysMax &&
        flexibilityDays == other.flexibilityDays &&
        homeAirportCode == other.homeAirportCode &&
        directFlightsOnly == other.directFlightsOnly &&
        _sameSet(interests, other.interests) &&
        _sameSet(preferredMonths, other.preferredMonths) &&
        _sameSet(excludedLocationIds, other.excludedLocationIds);
  }

  /// Dos listas como conjuntos equivalentes (ignora orden y repetidos).
  static bool _sameSet<T>(List<T> a, List<T> b) {
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }

  /// Porcentaje de completitud (0-100) medido SOLO sobre los tres
  /// campos que alimentan las recomendaciones:
  ///
  /// 1. Intereses (obligatorio para guardar).
  /// 2. Presupuesto (obligatorio para guardar).
  /// 3. Meses de disponibilidad (recomendado).
  ///
  /// Cada uno aporta un tercio. El estilo y la clase preferida son
  /// refinamientos OPCIONALES y NO cuentan en el porcentaje: marcarlos
  /// como obligatorios sin justificación penalizaría al usuario que ya
  /// aportó lo necesario para recibir recomendaciones útiles.
  int get completionPercentage {
    var filled = 0;
    if (interests.isNotEmpty) filled++;
    if (budgetMax > 0 && budgetMin >= 0) filled++;
    if (preferredMonths.isNotEmpty) filled++;
    return ((filled / 3) * 100).round();
  }

  /// Mensaje de error si los datos son INVÁLIDOS; `null` si son
  /// válidos (aunque estén incompletos). Un modelo con datos
  /// válidos-incompletos NO debe llegar aquí: usar
  /// [hasMissingRecommendedInfo] para eso.
  String? get validationError {
    if (interests.isEmpty) {
      return 'Selecciona al menos un tipo de viaje.';
    }
    if (budgetMin < 0) {
      return 'El presupuesto mínimo no puede ser negativo.';
    }
    if (budgetMax <= 0) {
      return 'Indica tu presupuesto máximo por viaje.';
    }
    if (budgetMax < budgetMin) {
      return 'El presupuesto máximo debe ser mayor o igual al mínimo.';
    }
    for (final month in preferredMonths) {
      if (month < 1 || month > 12) {
        return 'Los meses deben estar entre 1 y 12.';
      }
    }
    if (tripDaysMin != null &&
        (tripDaysMin! < tripDaysMinLimit || tripDaysMin! > tripDaysMaxLimit)) {
      return 'La duración mínima debe estar entre $tripDaysMinLimit y '
          '$tripDaysMaxLimit días.';
    }
    if (tripDaysMax != null &&
        (tripDaysMax! < tripDaysMinLimit || tripDaysMax! > tripDaysMaxLimit)) {
      return 'La duración máxima debe estar entre $tripDaysMinLimit y '
          '$tripDaysMaxLimit días.';
    }
    if (tripDaysMin != null &&
        tripDaysMax != null &&
        tripDaysMin! > tripDaysMax!) {
      return 'La duración mínima no puede ser mayor que la máxima.';
    }
    if (flexibilityDays != null &&
        (flexibilityDays! < 0 ||
            flexibilityDays! > flexibilityDaysLimit)) {
      return 'La flexibilidad debe estar entre 0 y $flexibilityDaysLimit días.';
    }
    if (homeAirportCode != null &&
        !RegExp(r'^[A-Za-z]{3}$').hasMatch(homeAirportCode!)) {
      return 'El aeropuerto base debe ser un código IATA de 3 letras.';
    }
    if (excludedLocationIds.length > excludedLocationsLimit) {
      return 'Puedes excluir hasta $excludedLocationsLimit destinos.';
    }
    return null;
  }

  /// Datos válidos pero con huecos recomendados (meses, estilo o clase
  /// sin definir). La UI los muestra como SUGERENCIA, no como error.
  List<String> get missingRecommendedInfo {
    final missing = <String>[];
    if (preferredMonths.isEmpty) {
      missing.add('Indica en qué meses puedes viajar.');
    }
    if (style == null) {
      missing.add('Elige tu estilo de viaje (opcional).');
    }
    if (preferredClass == null) {
      missing.add('Elige tu clase preferida (opcional).');
    }
    return missing;
  }

  TravelerPreferencesModel copyWith({
    List<TravelInterest>? interests,
    double? budgetMin,
    double? budgetMax,
    List<int>? preferredMonths,
    TravelStyle? style,
    TravelClass? preferredClass,
    TravelCompany? travelCompany,
    int? tripDaysMin,
    int? tripDaysMax,
    int? flexibilityDays,
    String? homeAirportCode,
    bool? directFlightsOnly,
    List<String>? excludedLocationIds,
    bool clearStyle = false,
    bool clearPreferredClass = false,
    bool clearTravelCompany = false,
    bool clearHomeAirportCode = false,
    bool clearDirectFlightsOnly = false,
  }) {
    return TravelerPreferencesModel(
      interests: interests ?? this.interests,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredMonths: preferredMonths ?? this.preferredMonths,
      style: clearStyle ? null : (style ?? this.style),
      preferredClass:
          clearPreferredClass ? null : (preferredClass ?? this.preferredClass),
      travelCompany:
          clearTravelCompany ? null : (travelCompany ?? this.travelCompany),
      tripDaysMin: tripDaysMin ?? this.tripDaysMin,
      tripDaysMax: tripDaysMax ?? this.tripDaysMax,
      flexibilityDays: flexibilityDays ?? this.flexibilityDays,
      homeAirportCode:
          clearHomeAirportCode ? null : (homeAirportCode ?? this.homeAirportCode),
      directFlightsOnly: clearDirectFlightsOnly
          ? null
          : (directFlightsOnly ?? this.directFlightsOnly),
      excludedLocationIds: excludedLocationIds ?? this.excludedLocationIds,
    );
  }

  /// Deserializa de forma TOLERANTE: un JSON corrupto o con campos
  /// faltantes/desconocidos nunca lanza; devuelve los campos válidos
  /// que sí se puedan leer y descarta el resto. Así una clave
  /// `traveler_prefs_<userId>` dañada no rompe la app.
  factory TravelerPreferencesModel.fromJson(Map<String, dynamic> json) {
    final rawInterests = json['interests'];
    final interests = <TravelInterest>[];
    if (rawInterests is List) {
      for (final item in rawInterests) {
        final parsed = TravelInterest.tryParse(item?.toString());
        if (parsed != null && !interests.contains(parsed)) {
          interests.add(parsed);
        }
      }
    }

    final rawMonths = json['preferredMonths'];
    final months = <int>[];
    if (rawMonths is List) {
      for (final item in rawMonths) {
        final month = item is int ? item : int.tryParse(item?.toString() ?? '');
        // Se descartan meses fuera de rango en vez de fallar.
        if (month != null &&
            month >= 1 &&
            month <= 12 &&
            !months.contains(month)) {
          months.add(month);
        }
      }
    }

    final rawClassKey = json['preferredClass']?.toString();
    TravelClass? preferredClass;
    for (final travelClass in TravelClass.values) {
      if (travelClass.storageKey == rawClassKey) {
        preferredClass = travelClass;
        break;
      }
    }

    final rawExcluded = json['excludedLocationIds'];
    final excludedLocationIds = <String>[];
    if (rawExcluded is List) {
      for (final item in rawExcluded) {
        if (excludedLocationIds.length >= excludedLocationsLimit) break;
        final id = item == null ? '' : item.toString().trim();
        if (id.isEmpty || excludedLocationIds.contains(id)) continue;
        excludedLocationIds.add(id);
      }
    }

    return TravelerPreferencesModel(
      interests: interests,
      budgetMin: _readDouble(json['budgetMin']),
      budgetMax: _readDouble(json['budgetMax']),
      preferredMonths: months,
      style: TravelStyle.tryParse(json['style']?.toString()),
      preferredClass: preferredClass,
      travelCompany: TravelCompany.tryParse(json['travelCompany']?.toString()),
      tripDaysMin:
          _readIntInRange(json['tripDaysMin'], tripDaysMinLimit, tripDaysMaxLimit),
      tripDaysMax:
          _readIntInRange(json['tripDaysMax'], tripDaysMinLimit, tripDaysMaxLimit),
      flexibilityDays:
          _readIntInRange(json['flexibilityDays'], 0, flexibilityDaysLimit),
      homeAirportCode: _readIataCode(json['homeAirportCode']),
      directFlightsOnly: json['directFlightsOnly'] is bool
          ? json['directFlightsOnly'] as bool
          : null,
      excludedLocationIds: excludedLocationIds,
    );
  }

  /// Lectura tolerante de números: acepta `num`, strings numéricos y
  /// cualquier otra cosa devolviendo 0 en vez de lanzar un cast.
  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Entero opcional dentro de `[min, max]`. Devuelve `null` (no un
  /// valor corregido) cuando el dato falta, no es número entero o está
  /// fuera de rango: el backend rechazaría el `PUT` y prefiero que el
  /// campo aparezca como "no declarado" antes que guardar un límite
  /// inválido que además bloquearía guardar.
  static int? _readIntInRange(Object? value, int min, int max) {
    int? parsed;
    if (value is int) {
      parsed = value;
    } else if (value is num && value == value.round()) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value.trim());
    }
    if (parsed == null || parsed < min || parsed > max) return null;
    return parsed;
  }

  /// Código IATA de 3 letras, normalizado a MAYÚSCULAS. Cualquier otra
  /// cosa (2 letras, número, texto raro) se descarta como `null`.
  static String? _readIataCode(Object? value) {
    if (value is! String) return null;
    final code = value.trim().toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : null;
  }

  Map<String, dynamic> toJson() => {
        'interests': interests.map((interest) => interest.name).toList(),
        'budgetMin': budgetMin,
        'budgetMax': budgetMax,
        'preferredMonths': preferredMonths,
        'style': style?.name,
        'preferredClass': preferredClass?.storageKey,
        // Campos ampliados: solo se envían los declarados, salvo
        // `excludedLocationIds`, que SIEMPRE va (aunque esté vacío):
        // así el usuario puede VACIAR la lista en el servidor con un
        // PUT que la traiga `[]`, en vez de que el backend conserve
        // las exclusiones anteriores.
        if (travelCompany != null) 'travelCompany': travelCompany!.name,
        if (tripDaysMin != null) 'tripDaysMin': tripDaysMin,
        if (tripDaysMax != null) 'tripDaysMax': tripDaysMax,
        if (flexibilityDays != null) 'flexibilityDays': flexibilityDays,
        if (homeAirportCode != null) 'homeAirportCode': homeAirportCode,
        if (directFlightsOnly != null) 'directFlightsOnly': directFlightsOnly,
        'excludedLocationIds': excludedLocationIds,
      };
}
