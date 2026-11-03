import 'package:flutter/material.dart';
import 'package:royal_airlines/core/theme/app_colors.dart';

/// NavItem
/// -------
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// CustomNavigationBar
/// --------------------
/// Barra flotante con gradiente de marca completo (no solo la píldora
/// activa) y un contorno dorado sutil — se lee como un elemento de
/// diseño en sí mismo, no solo una barra de navegación funcional.
class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavItem> items;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? 12 : 16),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  left: itemWidth * currentIndex,
                  top: 7,
                  bottom: 7,
                  width: itemWidth,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(items.length, (index) {
                    final isSelected = index == currentIndex;
                    final item = items[index];
                    return Expanded(
                      child: _NavBarItem(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => onTap(index),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: isSelected
              ? _SelectedContent(key: ValueKey('${item.label}_sel'), item: item)
              : _UnselectedContent(
                  key: ValueKey('${item.label}_uns'), item: item),
        ),
      ),
    );
  }
}

class _SelectedContent extends StatelessWidget {
  final NavItem item;
  const _SelectedContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.activeIcon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            item.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnselectedContent extends StatelessWidget {
  final NavItem item;
  const _UnselectedContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(item.icon,
          size: 23, color: AppColors.textOnPrimary.withValues(alpha: 0.55)),
    );
  }
}
