import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens_scope.dart';
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/lens/render_liquid_glass_lens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiquidGlassView API compatibility', () {
    testWidgets('builds with only the legacy children API', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            backgroundWidget: Container(color: Colors.blue),
            useImpellerBackdrop: false,
            children: const [
              LiquidGlass(
                position: LiquidGlassAlignPosition(
                    alignment: Alignment.center),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with no background and no children (new defaults)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            useImpellerBackdrop: false,
            child: const Center(child: Text('hello')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('provides a LiquidGlassLensScope to the child subtree',
        (tester) async {
      LiquidGlassLensScope? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            backgroundWidget: Container(color: Colors.blue),
            useImpellerBackdrop: false,
            child: Builder(builder: (context) {
              seen = LiquidGlassLensScope.maybeOf(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.useImpellerBackdrop, isFalse);
      expect(seen!.hasBackground, isTrue);
    });
  });

  group('LiquidGlassLens fallback behavior', () {
    testWidgets(
        'standalone lens on Skia degrades to frosted glass (no crash)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(children: [
            Container(color: Colors.green),
            Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: LiquidGlassLens(
                  useImpellerBackdrop: false,
                  child: const Center(child: Text('frosted')),
                ),
              ),
            ),
          ]),
        ),
      );
      await tester.pump();
      expect(find.text('frosted'), findsOneWidget);
      // Frosted fallback path: a BackdropFilter, no lens render object.
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(
        tester.renderObjectList(find.byElementPredicate((e) =>
            e is RenderObjectElement &&
            e.renderObject is RenderLiquidGlassLens)),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'lens inside a view without background on Skia also degrades',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            useImpellerBackdrop: false,
            child: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: LiquidGlassLens(
                  child: const Center(child: Text('frosted2')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('frosted2'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('visibility toggle animates without errors', (tester) async {
      Future<void> pumpLens(bool visible) {
        return tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: LiquidGlassLens(
                  useImpellerBackdrop: false,
                  visibility: visible,
                  visibilityDuration: const Duration(milliseconds: 100),
                ),
              ),
            ),
          ),
        );
      }

      await pumpLens(true);
      await pumpLens(false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await pumpLens(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('LiquidGlassLens refraction path (Skia capture)', () {
    testWidgets(
        'lens inside a view WITH background uses the capture render path',
        (tester) async {
      // Load the real shader programs from the package asset bundle.
      await LiquidGlassShaders.ensureLoaded();
      expect(LiquidGlassShaders.isLoaded, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            backgroundWidget: Container(color: Colors.purple),
            useImpellerBackdrop: false,
            child: Center(
              child: SizedBox(
                width: 220,
                height: 120,
                child: LiquidGlassLens(
                  shape: const RoundedRectangleShape(cornerRadius: 30),
                  child: const Center(child: Text('glass')),
                ),
              ),
            ),
          ),
        ),
      );
      // First frame paints via the synchronous capture fallback; pump a
      // few more so the post-frame capture lands and revision bumps.
      await tester.pump();
      await tester.pump();

      expect(find.text('glass'), findsOneWidget);
      final lensRenderObjects = tester.renderObjectList(
        find.byElementPredicate((e) =>
            e is RenderObjectElement &&
            e.renderObject is RenderLiquidGlassLens),
      );
      expect(lensRenderObjects, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lens keeps working inside a scrollable', (tester) async {
      await LiquidGlassShaders.ensureLoaded();

      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: LiquidGlassView(
            backgroundWidget: Container(color: Colors.orange),
            useImpellerBackdrop: false,
            child: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 300),
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 100,
                    child: LiquidGlassLens(
                      child: const Center(child: Text('scrolling glass')),
                    ),
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      controller.jumpTo(150);
      await tester.pump();
      // One extra frame: the transform tracker detects the move during
      // scene building and schedules the corrective repaint.
      await tester.pump();

      expect(find.text('scrolling glass'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dispose();
    });
  });
}
