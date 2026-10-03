import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  /// Whether to trigger a light haptic feedback on tap (default: true)
  final bool enableHaptic;

  /// Accessibility label for screen readers (VoiceOver / TalkBack)
  final String? semanticLabel;

  /// Optional accessibility hint (describes the result of the action)
  final String? semanticHint;

  /// Whether this widget acts as a button for accessibility tree
  final bool isButton;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 90),
    this.enableHaptic = true,
    this.semanticLabel,
    this.semanticHint,
    this.isButton = true,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
      if (widget.enableHaptic) HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gesture = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );

    // Wrap with Semantics to support VoiceOver (iOS) and TalkBack (Android)
    if (widget.semanticLabel != null || widget.isButton) {
      return Semantics(
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        button: widget.isButton,
        enabled: widget.onTap != null,
        onTap: widget.onTap,
        child: ExcludeSemantics(child: gesture),
      );
    }

    return gesture;
  }
}
