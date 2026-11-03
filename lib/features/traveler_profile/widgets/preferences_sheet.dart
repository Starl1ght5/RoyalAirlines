import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:royal_airlines/core/animations/app_motion.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/features/traveler_profile/controller/traveler_preferences_controller.dart';
import 'package:royal_airlines/features/traveler_profile/widgets/offer_alerts_prompt.dart';
import 'package:royal_airlines/features/traveler_profile/widgets/preferences_status_card.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/models/traveler_preferences_model.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';
import 'package:royal_airlines/shared/widgets/custom_textfield.dart';
import 'package:royal_airlines/shared/widgets/fade_slide_in.dart';
import 'package:royal_airlines/shared/widgets/section_title.dart';

/// PreferencesSheet
/// ----------------
/// Bottom sheet para declarar/editar las preferencias de viaje
/// (intereses, presupuesto, meses, estilo y clase + los campos de la
/// Etapa B: compañía de viaje, duración, flexibilidad, aeropuerto
/// base, vuelos directos y destinos excluidos). Sigue el patrón de
/// `EditProfileSheet`: [StatefulWidget] con [Form], validadores por
/// campo y guardado asíncrono.
///
/// Distingue mensajes de datos INVÁLIDOS (bloquean el guardado, en
/// rojo) de datos INCOMPLETOS (campos opcionales vacíos: nunca se
/// muestran como error).
///
/// El [TravelerPreferencesController] se recibe por parámetro porque
/// este sheet se abre bajo el Navigator raíz, fuera del subtree donde
/// vive el provider scoped de la pestaña "Para ti".
class PreferencesSheet extends StatefulWidget {
  const PreferencesSheet({super.key, required this.controller});

  final TravelerPreferencesController controller;

  @override
  State<PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<PreferencesSheet> {
  /// Valor centinela del dropdown de aeropuerto base: "todavía no lo
  /// defino". No es un código IATA, por eso no se guarda en el modelo
  /// (allí se convierte en `null`).
  static const String _noAirportValue = '__none__';

  /// Rango del slider de duración: el backend acepta 1-90 días pero
  /// el control de la UI arranca en 3 (viajes de fin de semana +
  /// traslados).
  static const double _tripDaysSliderMin = 3;
  static const double _tripDaysSliderMax = 90;
  static const double _flexibilitySliderMax = 30;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  final Set<TravelInterest> _selectedInterests = {};
  final Set<int> _selectedMonths = {};
  TravelStyle? _selectedStyle;
  TravelClass? _selectedClass;

  // Campos ampliados (Etapa B): compañía, duración, flexibilidad,
  // aeropuerto base, vuelos directos y destinos excluidos.
  TravelCompany? _selectedCompany;
  late RangeValues _tripRange;
  late double _flexibilityDays;
  String? _homeAirportCode;
  bool _directFlightsOnly = false;
  final Set<String> _excludedLocationIds = {};

  /// Catálogo de `GET /locations/`: alimenta el selector de aeropuerto
  /// base y el picker de destinos excluidos (el backend exige
  /// `Location.locationID`, no el código IATA).
  List<AirportModel> _airports = const [];
  bool _isLoadingCatalog = false;
  String? _catalogError;

  bool _isSaving = false;
  String? _errorMessage;
  String? _interestsError;

  @override
  void initState() {
    super.initState();
    final prefs = widget.controller.preferences;
    _selectedInterests.addAll(prefs.interests);
    _selectedMonths.addAll(prefs.preferredMonths);
    _selectedStyle = prefs.style;
    _selectedClass = prefs.preferredClass;
    _selectedCompany = prefs.travelCompany;
    _directFlightsOnly = prefs.directFlightsOnly ?? false;
    _homeAirportCode = prefs.homeAirportCode;
    _excludedLocationIds.addAll(prefs.excludedLocationIds);

    // El slider vive entre 3 y 90: un valor remoto fuera de ese rango
    // se recorta para que el control no reviente (la validación del
    // modelo sigue protegiendo lo que se guarda).
    var tripMin = (prefs.tripDaysMin ?? 3)
        .toDouble()
        .clamp(_tripDaysSliderMin, _tripDaysSliderMax)
        .toDouble();
    var tripMax = (prefs.tripDaysMax ?? 7)
        .toDouble()
        .clamp(_tripDaysSliderMin, _tripDaysSliderMax)
        .toDouble();
    if (tripMin > tripMax) {
      final swap = tripMin;
      tripMin = tripMax;
      tripMax = swap;
    }
    _tripRange = RangeValues(tripMin, tripMax);
    _flexibilityDays = (prefs.flexibilityDays ?? 0)
        .toDouble()
        .clamp(0, _flexibilitySliderMax)
        .toDouble();

    _minController = TextEditingController(
      text: prefs.budgetMin > 0 ? prefs.budgetMin.round().toString() : '',
    );
    _maxController = TextEditingController(
      text: prefs.budgetMax > 0 ? prefs.budgetMax.round().toString() : '',
    );

    _loadCatalog();
  }

  /// Carga `GET /locations/` una sola vez. Si falla (offline) la hoja
  /// sigue siendo usable: los controles que dependen del catálogo
  /// muestran el error con opción de reintentar.
  Future<void> _loadCatalog() async {
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });
    try {
      final airports = await HomeRepository().getAirports();
      if (!mounted) return;
      setState(() {
        _airports = airports;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalog = false;
        _catalogError =
            'No se pudo cargar el catálogo de aeropuertos. Revisa tu conexión.';
      });
    }
  }

  /// Etiqueta legible de un destino excluido: "Ciudad (ABC)" si el
  /// catálogo lo conoce y, si no, el propio id (nunca perder la
  /// exclusión aunque falle la red).
  String _excludedLabel(String locationId) {
    for (final airport in _airports) {
      if (airport.locationId == locationId) return airport.shortLabel;
    }
    return locationId;
  }

  /// Items del dropdown de aeropuerto base: la opción "sin definir" +
  /// el catálogo SIN códigos repetidos + el código actual si el
  /// catálogo ya no lo trae. `DropdownButtonFormField` exige que el
  /// valor inicial exista EXACTAMENTE una vez entre los items, así
  /// que esa garantía se arma aquí (el backend puede responder códigos
  /// duplicados o haber dado de baja una ciudad).
  List<DropdownMenuItem<String>> get _airportItems {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _noAirportValue,
        child: Text('Aún no lo defino'),
      ),
    ];
    final seen = <String>{_noAirportValue};
    for (final airport in _airports) {
      if (airport.code.isEmpty || !seen.add(airport.code)) continue;
      items.add(DropdownMenuItem(
        value: airport.code,
        child: Text(airport.shortLabel),
      ));
    }
    final current = _homeAirportCode;
    if (current != null && current.isNotEmpty && !seen.contains(current)) {
      items.add(DropdownMenuItem(value: current, child: Text(current)));
    }
    return items;
  }

  /// Abre el picker de destinos a excluir. Solo entran los que tienen
  /// `Location.locationID` (sin ese id el backend rechazaría el PUT
  /// con 404) y los que todavía no están en la lista.
  Future<void> _pickExcludedDestination() async {
    final available = _airports
        .where((airport) =>
            airport.locationId != null &&
            !_excludedLocationIds.contains(airport.locationId))
        .toList();

    final selected = await showModalBottomSheet<AirportModel>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => _ExcludedPickerSheet(airports: available),
    );
    if (selected?.locationId == null || !mounted) return;
    setState(() => _excludedLocationIds.add(selected!.locationId!));
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String? _validateBudgetMin(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      return 'Ingresa un monto válido';
    }
    return null;
  }

  String? _validateBudgetMax(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Indica tu presupuesto máximo';
    final value = double.tryParse(text);
    if (value == null || value < 0) return 'Ingresa un monto válido';
    final minValue = double.tryParse(_minController.text.trim()) ?? 0;
    if (value < minValue) {
      return 'Debe ser mayor o igual al mínimo';
    }
    return null;
  }

  Future<void> _handleSave() async {
    setState(() => _interestsError = null);

    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (_selectedInterests.isEmpty) {
      setState(() {
        _interestsError = 'Selecciona al menos un tipo de viaje.';
      });
    }
    if (!formIsValid || _selectedInterests.isEmpty) return;

    final candidate = TravelerPreferencesModel(
      interests: _selectedInterests.toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      budgetMin: double.tryParse(_minController.text.trim()) ?? 0,
      budgetMax: double.tryParse(_maxController.text.trim()) ?? 0,
      preferredMonths: _selectedMonths.toList()..sort(),
      style: _selectedStyle,
      preferredClass: _selectedClass,
      travelCompany: _selectedCompany,
      tripDaysMin: _tripRange.start.round(),
      tripDaysMax: _tripRange.end.round(),
      flexibilityDays: _flexibilityDays.round(),
      homeAirportCode: _homeAirportCode,
      directFlightsOnly: _directFlightsOnly,
      excludedLocationIds: _excludedLocationIds.toList()..sort(),
    );

    setState(() => _isSaving = true);
    final saved = await widget.controller.save(candidate);
    if (!mounted) return;

    if (saved) {
      // Ya vio el valor de dar sus datos: es el momento de ofrecer las alertas
      // de ofertas (una sola vez; ver offer_alerts_prompt.dart).
      await maybeAskOfferAlerts(context);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias guardadas'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      setState(() {
        _errorMessage = widget.controller.errorMessage ??
            'No se pudieron guardar tus preferencias.';
      });
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXl),
            ),
            boxShadow: AppShadows.floating,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const FadeSlideIn(
                    child: _SheetHeader(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: _errorMessage == null
                        ? const SizedBox.shrink(key: ValueKey('empty-error'))
                        : Padding(
                            key: ValueKey(_errorMessage),
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.lg),
                            child: _ErrorBanner(message: _errorMessage!),
                          ),
                  ),
                  FadeSlideIn(
                    index: 1,
                    child: _SectionBlock(
                      title: 'Tipos de viaje',
                      isRequired: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final interest in TravelInterest.values)
                                _ToggleChip(
                                  label: interest.label,
                                  selected:
                                      _selectedInterests.contains(interest),
                                  onTap: _isSaving
                                      ? null
                                      : () => setState(() {
                                            if (_selectedInterests
                                                .contains(interest)) {
                                              _selectedInterests
                                                  .remove(interest);
                                            } else {
                                              _selectedInterests.add(interest);
                                            }
                                          }),
                                ),
                            ],
                          ),
                          if (_interestsError != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _interestsError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 2,
                    child: _SectionBlock(
                      title: 'Presupuesto por viaje (COP)',
                      isRequired: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _minController,
                              label: 'Mínimo',
                              hint: 'Ej. 800000',
                              icon: Icons.sell_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _validateBudgetMin,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: CustomTextField(
                              controller: _maxController,
                              label: 'Máximo',
                              hint: 'Ej. 2500000',
                              icon: Icons.payments_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _validateBudgetMax,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 3,
                    child: _SectionBlock(
                      title: 'Meses en los que puedes viajar',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Opcional, pero ayuda a recomendar destinos en temporada.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (var month = 1; month <= 12; month++)
                                _ToggleChip(
                                  label: MonthLabels.short[month - 1],
                                  selected: _selectedMonths.contains(month),
                                  onTap: _isSaving
                                      ? null
                                      : () => setState(() {
                                            if (_selectedMonths
                                                .contains(month)) {
                                              _selectedMonths.remove(month);
                                            } else {
                                              _selectedMonths.add(month);
                                            }
                                          }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 4,
                    child: _SectionBlock(
                      title: 'Estilo de viaje',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final style in TravelStyle.values)
                            _ToggleChip(
                              label: style.label,
                              selected: _selectedStyle == style,
                              onTap: _isSaving
                                  ? null
                                  : () => setState(() {
                                        _selectedStyle = _selectedStyle == style
                                            ? null
                                            : style;
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 5,
                    child: _SectionBlock(
                      title: 'Clase preferida',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final travelClass in TravelClass.values)
                            _ToggleChip(
                              label: travelClass.shortLabel,
                              selected: _selectedClass == travelClass,
                              onTap: _isSaving
                                  ? null
                                  : () => setState(() {
                                        _selectedClass =
                                            _selectedClass == travelClass
                                                ? null
                                                : travelClass;
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 6,
                    child: _SectionBlock(
                      title: 'Compañía de viaje',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final company in TravelCompany.values)
                            _ToggleChip(
                              label: company.label,
                              selected: _selectedCompany == company,
                              onTap: _isSaving
                                  ? null
                                  : () => setState(() {
                                        _selectedCompany =
                                            _selectedCompany == company
                                                ? null
                                                : company;
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 7,
                    child: _SectionBlock(
                      title: 'Duración típica del viaje',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cuántos días suelen durar tus viajes (entre 3 y 90).',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${_tripRange.start.round()} a ${_tripRange.end.round()} días',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          RangeSlider(
                            values: _tripRange,
                            min: _tripDaysSliderMin,
                            max: _tripDaysSliderMax,
                            divisions: (_tripDaysSliderMax -
                                    _tripDaysSliderMin)
                                .round(),
                            activeColor: AppColors.primary,
                            inactiveColor:
                                AppColors.primary.withValues(alpha: 0.16),
                            labels: RangeLabels(
                              '${_tripRange.start.round()} días',
                              '${_tripRange.end.round()} días',
                            ),
                            onChanged: _isSaving
                                ? null
                                : (values) =>
                                    setState(() => _tripRange = values),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 8,
                    child: _SectionBlock(
                      title: 'Flexibilidad con las fechas',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cuántos días estás dispuesto a mover la salida o el regreso.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _flexibilityDays.round() == 0
                                ? 'Sin flexibilidad (fechas exactas)'
                                : '± ${_flexibilityDays.round()} días',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Slider(
                            value: _flexibilityDays,
                            min: 0,
                            max: _flexibilitySliderMax,
                            divisions: _flexibilitySliderMax.round(),
                            activeColor: AppColors.primary,
                            inactiveColor:
                                AppColors.primary.withValues(alpha: 0.16),
                            onChanged: _isSaving
                                ? null
                                : (value) =>
                                    setState(() => _flexibilityDays = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 9,
                    child: _SectionBlock(
                      title: 'Aeropuerto de origen habitual',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Para partir siempre desde tu ciudad (código IATA).',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_isLoadingCatalog)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Cargando aeropuertos…',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            )
                          else if (_catalogError != null) ...[
                            Text(
                              _catalogError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                height: 1.4,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _loadCatalog,
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 16),
                              label: const Text('Reintentar'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                            ),
                          ] else
                            DropdownButtonFormField<String>(
                              initialValue: _homeAirportCode ?? _noAirportValue,
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              dropdownColor: AppColors.surface,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textSecondary,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: 15,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              items: _airportItems,
                              onChanged: _isSaving
                                  ? null
                                  : (code) => setState(() {
                                        _homeAirportCode =
                                            code == null || code == _noAirportValue
                                                ? null
                                                : code;
                                      }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 10,
                    child: _SectionBlock(
                      title: 'Tipo de vuelo',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.flight_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              'Solo vuelos directos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Switch(
                            value: _directFlightsOnly,
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(
                                    () => _directFlightsOnly = value),
                            activeThumbColor: AppColors.textOnPrimary,
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.surfaceVariant,
                            inactiveThumbColor: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    index: 11,
                    child: _SectionBlock(
                      title: 'Destinos que no quiero ver',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Opcional: exclúyelos y no aparecerán en tus recomendaciones (hasta 100).',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          if (_excludedLocationIds.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final locationId
                                    in _excludedLocationIds)
                                  _ExcludedChip(
                                    label: _excludedLabel(locationId),
                                    onTap: _isSaving
                                        ? null
                                        : () => setState(() =>
                                            _excludedLocationIds
                                                .remove(locationId)),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          if (_isLoadingCatalog)
                            const Text(
                              'Cargando destinos…',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _isSaving ||
                                      _catalogError != null ||
                                      _excludedLocationIds.length >=
                                          TravelerPreferencesModel
                                              .excludedLocationsLimit
                                  ? null
                                  : _pickExcludedDestination,
                              icon: const Icon(Icons.add_location_alt_outlined,
                                  size: 16),
                              label: Text(
                                _excludedLocationIds.isEmpty
                                    ? 'Excluir un destino'
                                    : 'Excluir otro destino',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  CustomButton(
                    label: 'Guardar preferencias',
                    icon: Icons.check_rounded,
                    isLoading: _isSaving,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.tune_rounded,
            color: AppColors.gold,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferencias de viaje',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Los intereses y el presupuesto son obligatorios; el resto '
                'puedes dejarlo para después.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.child,
    this.isRequired = false,
  });

  final String title;
  final Widget child;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(title: title)),
            if (isRequired)
              const Text(
                'Obligatorio',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExcludedChip extends StatelessWidget {
  const _ExcludedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border:
                Border.all(color: AppColors.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.error,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet con el catálogo de destinos que se pueden excluir.
/// Devuelve el [AirportModel] elegido, o `null` si se cierra sin
/// elegir. Solo recibe los que aún no están excluidos y que sí tienen
/// `Location.locationID`.
class _ExcludedPickerSheet extends StatelessWidget {
  const _ExcludedPickerSheet({required this.airports});

  final List<AirportModel> airports;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Excluir destino',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 21),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (airports.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: Text(
                'Ya excluiste todos los destinos disponibles.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                itemCount: airports.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.divider, height: 1),
                itemBuilder: (context, index) {
                  final airport = airports[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      airport.shortLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      airport.country,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onTap: () => Navigator.of(context).pop(airport),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
