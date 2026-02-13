import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? description;
  final IconData icon;
  final StatVariant variant;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.description,
    this.variant = StatVariant.defaultV,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors(variant);

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.foreground,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum StatVariant { defaultV, success, danger, neutral }

class _VColors {
  final Color bg;
  final Color border;
  final Color iconBg;
  final Color iconFg;
  _VColors(this.bg, this.border, this.iconBg, this.iconFg);
}

_VColors _variantColors(StatVariant v) {
  switch (v) {
    case StatVariant.success:
      return _VColors(
        const Color(0xFFECFDF5), // emerald-50
        const Color(0xFFD1FAE5), // emerald-100
        const Color(0xFFD1FAE5),
        const Color(0xFF059669), // emerald-600
      );
    case StatVariant.danger:
      return _VColors(
        const Color(0xFFFFF1F2), // rose-50
        const Color(0xFFFFE4E6), // rose-100
        const Color(0xFFFFE4E6),
        const Color(0xFFE11D48), // rose-600
      );
    case StatVariant.neutral:
      return _VColors(
        const Color(0xFFF8FAFC), // slate-50
        const Color(0xFFF1F5F9), // slate-100
        const Color(0xFFE2E8F0), // slate-200
        const Color(0xFF475569), // slate-600
      );
    case StatVariant.defaultV:
    default:
      return _VColors(
        AppTheme.card,
        AppTheme.border,
        AppTheme.primary.withOpacity(0.10),
        AppTheme.primary,
      );
  }
}
