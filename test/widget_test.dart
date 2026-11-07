import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tam_app/services/app_provider.dart';
import 'package:tam_app/widgets/animated_pressable.dart';
import 'package:tam_app/widgets/tam_logo_widget.dart';

void main() {
  testWidgets('AnimatedPressable preserves child text semantics when semanticLabel is null',
      (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedPressable(
            onTap: () => tapped = true,
            child: const Text('Start Quiz'),
          ),
        ),
      ),
    );

    expect(find.text('Start Quiz'), findsOneWidget);
    await tester.tap(find.text('Start Quiz'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('TamLogoWidget renders localized subtitle based on AppProvider language',
      (WidgetTester tester) async {
    final provider = AppProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: TamLogoWidget(showTagline: true),
          ),
        ),
      ),
    );

    expect(find.textContaining('منصة'), findsOneWidget);
  });
}
