import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/core/theme/app_spacing.dart';
import 'package:royal_airlines/core/utils/currency_formatter.dart';
import 'package:royal_airlines/features/home/repository/home_repository.dart';
import 'package:royal_airlines/models/airport_model.dart';
import 'package:royal_airlines/services/price_history_service.dart';

/// PriceHistoryCard
/// ----------------
/// Gráfica del histórico de precios de UNA ruta
/// (`GET /prices/history`), en **USD** con la etiqueta explícita.
///
/// Se usa en dos sitios:
///  - ficha de VUELO (hoja de tarifas): con [originCode] y
///    [destinationCode] del propio vuelo;
///  - ficha de DESTINO (hoja de recomendación): con
///    [PriceHistoryCard.forDestination], que resuelve el origen con el
///    catálogo `GET /locations/` (primer aeropuerto que no sea el
///    destino, mismo criterio que el resto de la app).
///
/// Estados: cargando, error con reintento, vacío ("aún no hay
/// historial" — una ruta sin datos devuelve `[]`, NO es error) y la
/// gráfica propiamente dicha. Los precios solo los escribe el backend
/// (tarea 03:30), así que esta tarjeta es de SOLO lectura.
class PriceHistoryCard extends StatefulWidget {
  const PriceHistoryCard({
    super.key,
    this.originCode,
    required this.destinationCode,
    required this.departureDate,
    this.days = 90,
  });

  /// Origen `null` = resolverlo con el catálogo (ver [forDestination]).
  final String? originCode;

  final String destinationCode;

  /// Fecha de salida del vuelo/ruta (llega como `departureDate` al
  /// backend en formato `yyyy-MM-dd`).
  final DateTime departureDate;

  /// Ventana del histórico, 1-180 días.
  final int days;

  /// Para la ficha de un destino recomendado: aún no hay vuelo concreto,
  /// así que el origen se resuelve con `HomeRepository.getAirports()`.
  factory PriceHistoryCard.forDestination({
    required String destinationCode,
    DateTime? departureDate,
    int days = 180,
  }) {
    return PriceHistoryCard(
      originCode: "CTG",
      destinationCode: destinationCode,
      departureDate:
          departureDate ?? DateTime.now().add(const Duration(days: 14)),
      days: days,
    );
  }

  @override
  State<PriceHistoryCard> createState() => _PriceHistoryCardState();
}

class _PriceHistoryCardState extends State<PriceHistoryCard> {
  final PriceHistoryService _service = PriceHistoryService();

  String? _originCode;
  List<PriceSnapshot> _snapshots = const [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _originResolved = false;

  @override
  void initState() {
    super.initState();
    _originCode = widget.originCode;
    if (_originCode != null && _originCode!.isNotEmpty) {
      // Se difiere al primer frame: `_load()` llama a setState y eso no
      // debe ocurrir de forma SÍNCRONA dentro de initState (y sin
      // origen declarado, _resolveOrigin ya es asíncrono por dentro).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else {
      _resolveOrigin();
    }
  }

  /// Sin origen declarado se busca el primero que no sea el destino.
  Future<void> _resolveOrigin() async {
    try {
      final airports = await HomeRepository().getAirports();
      final match = airports.cast<AirportModel?>().firstWhere(
            (airport) => airport?.code != widget.destinationCode,
            orElse: () => null,
          );
      _originCode = match?.code;
    } catch (_) {
      // Sin catálogo no hay ruta a consultar: se muestra el estado de
      // error con reintento (que vuelve a intentar TODO, incluido el
      // catálogo).
      _originCode = null;
    } finally {
      _originResolved = true;
      if (mounted && _originCode != null && _originCode!.isNotEmpty) {
        _load();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage ??=
              'No se pudo determinar un origen para esta ruta. Revisa tu conexión.';
        });
      }
    }
  }

  Future<void> _load() async {
    final origin = _originCode;
    if (origin == null || origin.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshots = await _service.fetch(
        origin: origin,
        destination: widget.destinationCode,
        departureDate: widget.departureDate,
        days: widget.days,
      );
      if (!mounted) return;
      setState(() {
        _snapshots = snapshots;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No se pudo cargar el historial de precios. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Historial de precios',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Text(
                  'USD',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Precio mínimo por día en la ruta $_routeLabel',
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBody(),
        ],
      ),
    );
  }

  String get _routeLabel {
    final origin = _originCode;
    if (origin == null || origin.isEmpty) {
      return widget.destinationCode;
    }
    return '$origin → ${widget.destinationCode}';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.2,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.error,
            ),
          ),
          TextButton.icon(
            onPressed:
                _originResolved && _originCode != null ? _load : _restart,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      );
    }

    if (_snapshots.isEmpty) {
      // `[]` NO es error: la ruta todavía no acumuló datos (los
      // snapshots los escribe la tarea de las 03:30).
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Aún no hay historial para esta ruta. '
          'Cuando haya vuelos, aquí verás la evolución del precio mínimo.',
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final chart = _snapshots.length > 1 ? _chart() : _singlePoint();
    final first = _snapshots.first;
    final last = _snapshots.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _Stat(
              label: 'Mínimo',
              value: CurrencyFormatter.usd(
                _snapshots.map((snapshot) => snapshot.minPriceUsd).reduce(
                      (a, b) => a < b ? a : b,
                    ),
              ),
            ),
            _Stat(
              label: 'Máximo',
              value: CurrencyFormatter.usd(
                _snapshots.map((snapshot) => snapshot.minPriceUsd).reduce(
                      (a, b) => a > b ? a : b,
                    ),
              ),
            ),
            _Stat(
                label: 'Último dato',
                value: CurrencyFormatter.usd(last.minPriceUsd)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        chart,
        const SizedBox(height: AppSpacing.xs),
        // Fechas FUERA del gráfico: en el eje X no hay espacio para
        // etiquetas legibles en una tarjeta angosta.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _shortDate(first.capturedDate),
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              _shortDate(last.capturedDate),
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Un solo snapshot: sin rango en X la línea no se dibuja, así que
  /// se muestra el punto con su valor.
  Widget _singlePoint() {
    final snapshot = _snapshots.first;
    return Container(
      height: 64,
      alignment: Alignment.center,
      child: Text(
        CurrencyFormatter.usd(snapshot.minPriceUsd),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _chart() {
    final values = _snapshots.map((snapshot) => snapshot.minPriceUsd);
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = max - min;

    // Rango vertical con aire: sin él, precios planos producirían
    // minY == maxY y una gráfica inutilizable.
    final pad = span > 0 ? span * 0.15 : (max > 0 ? max * 0.05 : 1);
    final minY = min - pad;
    final maxY = max + pad;
    final interval = (maxY - minY) / 4;

    final spots = [
      for (var i = 0; i < _snapshots.length; i++)
        FlSpot(i.toDouble(), _snapshots[i].minPriceUsd),
    ];

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (_snapshots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  CurrencyFormatter.usdShort(value),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 2.2,
              color: AppColors.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "28 oct" sin depender de intl (la app no lo usa en el front).
  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String _shortDate(DateTime date) {
    final month =
        date.month >= 1 && date.month <= 12 ? _months[date.month - 1] : '';
    return '${date.day} $month';
  }

  void _restart() {
    setState(() {
      _originResolved = false;
      _originCode = widget.originCode;
    });
    if (_originCode != null && _originCode!.isNotEmpty) {
      _load();
    } else {
      _resolveOrigin();
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
