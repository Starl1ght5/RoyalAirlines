import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';
import 'package:royal_airlines/features/favorites/widgets/favorite_button.dart';
import 'package:royal_airlines/models/airport_model.dart';

String _imageUrlFor(String code) {
  const urls = {
    'MAD':
        'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=640&q=75',
    'DOH':
        'https://images.unsplash.com/photo-1578895101408-1a36b834405b?w=640&q=75',
    'MIA':
        'https://images.unsplash.com/photo-1535498730771-e735b998cd64?w=640&q=75',
    'CTG':
        'https://images.unsplash.com/photo-1536098561742-ca998e48cbcc?w=640&q=75',
    'CLO':
        'https://images.unsplash.com/photo-1516026672322-bc52d61a55d5?w=640&q=75',
  };
  return urls[code] ??
      'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=640&q=75';
}

/// DestinationList
/// ---------------
/// Lista horizontal de destinos populares. Tarjetas de 128x156 (antes
/// 134x168) — proporción 4:5 ligeramente más compacta, que permite ver
/// "asomarse" una cuarta tarjeta en el borde en pantallas de 412dp,
/// dando la pista visual de que hay más contenido para deslizar.
class DestinationList extends StatelessWidget {
  final List<AirportModel> destinations;
  final ValueChanged<AirportModel>? onDestinationTap;

  const DestinationList({
    super.key,
    required this.destinations,
    this.onDestinationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 156,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: destinations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return _DestinationCard(
            destination: destination,
            onTap: onDestinationTap == null
                ? null
                : () => onDestinationTap!(destination),
          );
        },
      ),
    );
  }
}

class _DestinationCard extends StatefulWidget {
  final AirportModel destination;
  final VoidCallback? onTap;

  const _DestinationCard({required this.destination, this.onTap});

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 128,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _imageUrlFor(widget.destination.code),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: AppColors.gold,
                      size: 30,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.primaryDark.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: FavoriteButton(
                    // El catálogo de Home SÍ trae `locationId`; `code`
                    // queda como respaldo si algún día llega en null.
                    hint: widget.destination.locationId,
                    code: widget.destination.code,
                    chip: true,
                    inactiveColor: Colors.white,
                    activeColor: AppColors.error,
                    tooltip: 'Guardar destino',
                  ),
                ),
                Positioned(
                  left: 11,
                  right: 11,
                  bottom: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.destination.city,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      Text(
                        widget.destination.country,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.destination.code,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
