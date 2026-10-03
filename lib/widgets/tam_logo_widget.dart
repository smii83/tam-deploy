import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';

/// Reusable TAM logo widget — auto-switches between dark/light logo.
/// [size] controls the height of the logo image (width scales proportionally).
/// [showTagline] shows the platform name below the logo.
class TamLogoWidget extends StatelessWidget {
  final double size;
  final bool showTagline;
  final Color? taglineColor;

  const TamLogoWidget({
    super.key,
    this.size = 80,
    this.showTagline = false,
    this.taglineColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final logoAsset = isDark
        ? 'assets/images/logo_dark.png'
        : 'assets/images/logo_light.png';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          logoAsset,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'منصة تـم التعليمية',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: taglineColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : const Color(0xFF6C63FF).withValues(alpha: 0.8)),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
