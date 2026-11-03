import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/theme/app_theme.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/flights/widgets/fare_details_sheet.dart';
import 'package:royal_airlines/models/flight_model.dart';
import 'package:royal_airlines/models/travel_class.dart';
import 'package:royal_airlines/shared/widgets/custom_button.dart';

/// _CompareRow
/// -----------
/// Definición declarativa de una fila de la tabla: qué texto mostrar por
/// vuelo ([display]) y, opcionalmente, qué número usar para decidir cuál
/// es el mejor valor ([metric]). Si [metric] es null la fila es solo
/// informativa y nunca resalta un ganador.
class _CompareRow {
  const _CompareRow({
    required this.label,
    required this.display,
    this.metric,
  }) : lowerIsBetter = true;

  final String label;
  final String Function(FlightModel flight) display;
  final num? Function(FlightModel flight)? metric;
  final bool lowerIsBetter;
}

/// FlightComparisonScreen
/// ----------------------
/// Compara 2-3 vuelos de los resultados de búsqueda, uno por columna.
/// Resalta en verde el mejor valor de cada criterio y permite elegir
/// directamente un vuelo para continuar con la reserva.
///
/// La pantalla NO conoce el flujo de reserva: recibe [onSelect] (que en
/// FlightsScreen es `_handleFlightSelected`, con su guard de login y su
/// navegación a LegBookingScreen), así que "Ida", "Regreso" y "Solo ida"
/// funcionan igual sin duplicar lógica.
class FlightComparisonScreen extends StatefulWidget {
  const FlightComparisonScreen({
    super.key,
    required this.flights,
    required this.onSelect,
    this.refreshFlight,
    this.onRemove,
  });

  final List<FlightModel> flights;

  /// Se invoca al elegir vuelo + tarifa desde la comparación.
  final void Function(FlightModel flight, FareModel fare) onSelect;

  /// Opcional: reconsulta el detalle de un vuelo (tarifas y cupos
  /// frescos). Se usa `FlightController.refreshFlightDetail`, que nunca
  /// lanza: si el backend falla devuelve el vuelo original.
  final Future<FlightModel> Function(FlightModel flight)? refreshFlight;

  /// Opcional: avisa al controller que el usuario quitó un vuelo de la
  /// comparación, para mantener sincronizados los chips de la lista.
  final void Function(FlightModel flight)? onRemove;

  @override
  State<FlightComparisonScreen> createState() => _FlightComparisonScreenState();
}

class _FlightComparisonScreenState extends State<FlightComparisonScreen> {
  static const double _labelWidth = 92;
  static const double _minColumnWidth = 120;

  late List<FlightModel> _flights;
  late bool _isRefreshing;

  @override
  void initState() {
    super.initState();
    _flights = List.of(widget.flights);
    _isRefreshing = widget.refreshFlight != null;
    _refreshAll();
  }

  /// Refresca todos los vuelos en paralelo. Se mapea por id al volver,
  /// por si el usuario quitó algún vuelo mientras la consulta corría.
  Future<void> _refreshAll() async {
    final refresh = widget.refreshFlight;
    if (refresh == null) return;

    try {
      final fresh = await Future.wait(_flights.map(refresh));
      if (!mounted) return;
      final byId = {for (final f in fresh) f.id: f};
      setState(() {
        _flights = [for (final f in _flights) byId[f.id] ?? f];
      });
    } catch (_) {
      // Se conservan los datos de la búsqueda; nunca bloquea la UI.
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _remove(FlightModel flight) {
    widget.onRemove?.call(flight);
    setState(() {
      _flights = _flights.where((f) => f.id != flight.id).toList();
    });
    // Con un solo vuelo ya no hay nada que comparar.
    if (_flights.length < 2) Navigator.of(context).pop();
  }

  Future<void> _choose(FlightModel flight) async {
    final fare = await FareDetailsSheet.show(context, flight);
    if (fare == null || !mounted) return;
    widget.onSelect(flight, fare);
  }

  // ---------------------------------------------------------------------
  // Definición de filas
  // ---------------------------------------------------------------------

  List<_CompareRow> _generalRows() {
    return [
      _CompareRow(
        label: 'Precio desde',
        display: (f) => CurrencyFormatter.cop(f.cheapestFare.price),
        metric: (f) => f.cheapestFare.price,
      ),
      _CompareRow(
        label: 'Duración',
        display: (f) => _formatDuration(f.duration),
        metric: (f) => f.duration.inMinutes,
      ),
      _CompareRow(
        label: 'Escalas',
        display: (f) => f.stopsLabel,
        metric: (f) => f.stops,
      ),
      _CompareRow(
        label: 'Salida',
        display: (f) => _formatTime(f.departureTime),
      ),
      _CompareRow(
        label: 'Llegada',
        display: (f) {
          final days = _dayDifference(f.departureTime, f.arrivalTime);
          final time = _formatTime(f.arrivalTime);
          return days > 0 ? '$time (+$days)' : time;
        },
      ),
      _CompareRow(
        label: 'Aeronave',
        display: (f) => f.aircraft.isEmpty ? '—' : f.aircraft,
      ),
      _CompareRow(
        label: 'Ocupación',
        display: (f) {
          final forecast = f.demandForecast;
          final percent = (forecast.fillProbability * 100).round();
          return '$percent% · ${forecast.level}';
        },
        // Menos ocupado = más disponibilidad y menos riesgo de agotarse.
        metric: (f) => f.demandForecast.fillProbability,
      ),
      _CompareRow(
        label: 'Tendencia',
        display: (f) {
          final forecast = f.priceForecast;
          return forecast.isRising
              ? 'Sube ~${forecast.changePercent}%'
              : 'Puede bajar ~${forecast.changePercent}%';
        },
        // Negativo = se espera que baje, por eso "menor es mejor".
        metric: (f) => f.priceForecast.isRising
            ? f.priceForecast.changePercent
            : -f.priceForecast.changePercent,
      ),
    ];
  }

  /// Una fila por cada clase que al menos un vuelo ofrezca. Si un vuelo
  /// no tiene esa clase se muestra "—" y no participa en el ranking.
  List<_CompareRow> _fareRows() {
    return [
      for (final travelClass in TravelClass.values)
        if (_flights.any((f) => f.fareFor(travelClass) != null))
          _CompareRow(
            label: travelClass.shortLabel,
            display: (f) {
              final fare = f.fareFor(travelClass);
              return fare == null ? '—' : CurrencyFormatter.cop(fare.price);
            },
            metric: (f) => f.fareFor(travelClass)?.price,
          ),
    ];
  }

  // ---------------------------------------------------------------------
  // Cálculo de ganadores
  // ---------------------------------------------------------------------

  /// Índices de los vuelos con el mejor valor de la fila. Devuelve vacío
  /// si la fila no tiene métrica, si hay menos de 2 valores comparables
  /// o si todos empatan (resaltar a todos no aporta información).
  Set<int> _winnersFor(_CompareRow row) {
    final metric = row.metric;
    if (metric == null) return const {};

    final values = _flights.map(metric).toList();
    final valid = values.whereType<num>().toList();
    if (valid.length < 2) return const {};

    final best = valid.reduce(
      (a, b) => (row.lowerIsBetter ? a <= b : a >= b) ? a : b,
    );
    if (valid.every((v) => v == best)) return const {};

    return {
      for (var i = 0; i < values.length; i++)
        if (values[i] == best) i,
    };
  }

  List<int> _winCounts(List<_CompareRow> rows) {
    final counts = List<int>.filled(_flights.length, 0);
    for (final row in rows) {
      for (final index in _winnersFor(row)) {
        counts[index]++;
      }
    }
    return counts;
  }

  // ---------------------------------------------------------------------
  // Formato
  // ---------------------------------------------------------------------

  static String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }

  static int _dayDifference(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final general = _generalRows();
    final fares = _fareRows();
    final winCounts = _winCounts([...general, ...fares]);

    final maxWins = winCounts.isEmpty
        ? 0
        : winCounts.reduce((a, b) => a > b ? a : b);
    final topPickIndex =
        maxWins > 0 && winCounts.where((c) => c == maxWins).length == 1
            ? winCounts.indexOf(maxWins)
            : -1;

    final first = _flights.isNotEmpty ? _flights.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              'Comparar vuelos',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (first != null)
              Text(
                '${first.origin.code} → ${first.destination.code}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_isRefreshing)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.divider,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = _flights.length;
                  final available =
                      constraints.maxWidth - AppSpacing.lg * 2 - _labelWidth;
                  final double columnWidth = count == 0
                      ? _minColumnWidth
                      : (available / count)
                          .clamp(_minColumnWidth, 240.0)
                          .toDouble();
                  final tableWidth = _labelWidth + columnWidth * count;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Scroll horizontal solo si 3 columnas no caben.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: tableWidth,
                            child: _buildTable(
                              general: general,
                              fares: fares,
                              winCounts: winCounts,
                              topPickIndex: topPickIndex,
                              columnWidth: columnWidth,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'El mejor valor de cada criterio aparece resaltado. '
                          'Precios por pasajero, incluyen tasas.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable({
    required List<_CompareRow> general,
    required List<_CompareRow> fares,
    required List<int> winCounts,
    required int topPickIndex,
    required double columnWidth,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      // El borde va en foregroundDecoration para que no reste espacio al
      // contenido: con `decoration.border` las filas (ancho fijo = tableWidth)
      // desbordaban 2px a la derecha (1px de borde por lado).
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera: un bloque por vuelo.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: _labelWidth),
                for (var i = 0; i < _flights.length; i++)
                  _HeaderCell(
                    flight: _flights[i],
                    width: columnWidth,
                    wins: winCounts[i],
                    isTopPick: i == topPickIndex,
                    onRemove: () => _remove(_flights[i]),
                  ),
              ],
            ),
          ),
          for (final row in general) _buildRow(row, columnWidth),
          if (fares.isNotEmpty) ...[
            Container(
              color: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: const Text(
                'TARIFAS POR CLASE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (final row in fares) _buildRow(row, columnWidth),
          ],
          // Pie: botón para elegir cada vuelo.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: _labelWidth),
              for (final flight in _flights)
                Container(
                  width: columnWidth,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: SizedBox(
                    height: 48,
                    child: CustomButton(
                      label: 'Elegir',
                      onPressed: () => _choose(flight),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_CompareRow row, double columnWidth) {
    final winners = _winnersFor(row);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabelCell(label: row.label, width: _labelWidth),
          for (var i = 0; i < _flights.length; i++)
            _ValueCell(
              text: row.display(_flights[i]),
              isWinner: winners.contains(i),
              width: columnWidth,
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.flight,
    required this.width,
    required this.wins,
    required this.isTopPick,
    required this.onRemove,
  });

  final FlightModel flight;
  final double width;
  final int wins;
  final bool isTopPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  flight.airline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            flight.flightNumber,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${flight.origin.code} → ${flight.destination.code}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isTopPick)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Text(
                'Mejor balance',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            )
          else if (wins > 0)
            Text(
              'Gana en $wins',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _LabelCell extends StatelessWidget {
  const _LabelCell({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({
    required this.text,
    required this.isWinner,
    required this.width,
  });

  final String text;
  final bool isWinner;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isWinner ? AppColors.success.withValues(alpha: 0.10) : null,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner) ...[
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                color: isWinner ? AppColors.success : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
