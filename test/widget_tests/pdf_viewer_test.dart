import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/library/screens/pdf_viewer_screen.dart';
import 'package:mobile/core/res/styles.dart';

/// Tests simplifiés pour PdfViewerScreen
/// Ces tests vérifient l'UI sans mocking complexe du PDF
void main() {
  const testTitle = 'Test PDF Document';
  const testUrl = 'http://example.com/test.pdf';

  group('PdfViewerScreen UI Tests', () {
    testWidgets('renders app bar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le titre
      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('renders back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le bouton retour
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier l'indicateur de chargement
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement du PDF...'), findsOneWidget);
    });

    testWidgets('back button is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PdfViewerScreen(
                          title: testTitle,
                          url: testUrl,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open PDF'),
                ),
              ),
            ),
          ),
        ),
      );

      // Ouvrir le PDF viewer
      await tester.tap(find.text('Open PDF'));
      await tester.pumpAndSettle();

      // Vérifier que l'écran est ouvert
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap sur le bouton retour
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Vérifier que nous sommes revenus
      expect(find.text('Open PDF'), findsOneWidget);
    });
  });

  group('PdfViewerScreen Loading State', () {
    testWidgets('shows correct loading UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier l'indicateur de couleur dorée (AppColors.gold)
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.color, AppColors.gold);
    });
  });

  group('PdfViewerScreen Theme', () {
    testWidgets('uses correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PdfViewerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le Scaffold avec la couleur de fond
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.navy);
    });
  });
}
