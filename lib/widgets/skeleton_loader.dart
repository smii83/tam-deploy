import 'package:flutter/material.dart';

/// A shimmer-effect skeleton loader widget.
/// Shows a pulsing placeholder while content is loading — much more premium
/// than a plain CircularProgressIndicator.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A3C) : const Color(0xFFE8E8F0);
    final highlightColor = isDark ? const Color(0xFF3A3A52) : const Color(0xFFF5F5FF);

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            colors: [
              Color.lerp(baseColor, highlightColor, _animation.value)!,
              Color.lerp(highlightColor, baseColor, _animation.value)!,
              Color.lerp(baseColor, highlightColor, _animation.value)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A full lesson card skeleton — matches the shape of _buildLessonCard
class LessonCardSkeleton extends StatelessWidget {
  const LessonCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 44, height: 44, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 14,
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 80, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SkeletonLoader(width: 28, height: 28, borderRadius: 14),
        ],
      ),
    );
  }
}

/// A full PDF card skeleton — matches the shape of PDFsScreen list item
class PdfCardSkeleton extends StatelessWidget {
  const PdfCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const SkeletonLoader(width: 46, height: 46, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 13,
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 60, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SkeletonLoader(width: 56, height: 32, borderRadius: 10),
        ],
      ),
    );
  }
}

/// A subject card skeleton — matches home screen grid
class SubjectCardSkeleton extends StatelessWidget {
  const SubjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 38, height: 38, borderRadius: 12),
          const Spacer(),
          const SkeletonLoader(width: 50, height: 9),
          const SizedBox(height: 6),
          const SkeletonLoader(height: 13),
        ],
      ),
    );
  }
}
