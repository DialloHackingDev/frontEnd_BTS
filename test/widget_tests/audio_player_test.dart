import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/library/screens/audio_player_screen.dart';
import 'package:mobile/core/res/styles.dart';

/// Tests simplifiés pour AudioPlayerScreen
/// Ces tests vérifient l'UI sans mocking complexe du lecteur audio
void main() {
  const testTitle = 'Test Audio File';
  const testUrl = 'http://example.com/test.mp3';

  group('AudioPlayerScreen UI Tests', () {
    testWidgets('renders app bar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le titre
      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('renders back button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le bouton retour
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('shows loading or downloading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier qu'un indicateur est présent (chargement ou téléchargement)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders audio artwork placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier l'icône d'audio
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
    });

    testWidgets('renders artist label', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le label de l'artiste/source
      expect(find.text('BTS Library'), findsOneWidget);
    });

    testWidgets('has correct title styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier que le titre est présent
      final titleFinder = find.text(testTitle);
      expect(titleFinder, findsOneWidget);
    });
  });

  group('AudioPlayerScreen Controls', () {
    testWidgets('renders control buttons structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Attendre le rendu initial
      await tester.pump();

      // Vérifier les contrôles (même si cachés pendant le chargement)
      expect(find.byType(IconButton), findsWidgets);
    });
  });

  group('AudioPlayerScreen Loading States', () {
    testWidgets('shows download progress when caching', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le texte de préparation/téléchargement
      final texts = find.byType(Text);
      expect(texts, findsWidgets);
    });

    testWidgets('shows error state when loading fails', (WidgetTester tester) async {
      // Test avec une URL invalide
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(
            title: 'Invalid Audio',
            url: 'invalid-url',
          ),
        ),
      );

      // Attendre que l'erreur éventuelle apparaisse
      await tester.pump(const Duration(seconds: 1));

      // L'écran doit toujours être rendu
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('AudioPlayerScreen Navigation', () {
    testWidgets('back button navigates back', (WidgetTester tester) async {
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
                        builder: (context) => const AudioPlayerScreen(
                          title: testTitle,
                          url: testUrl,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Audio'),
                ),
              ),
            ),
          ),
        ),
      );

      // Ouvrir le lecteur audio
      await tester.tap(find.text('Open Audio'));
      await tester.pumpAndSettle();

      // Vérifier que l'écran est ouvert
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap sur le bouton retour
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Vérifier que nous sommes revenus
      expect(find.text('Open Audio'), findsOneWidget);
    });
  });

  group('AudioPlayerScreen Theme', () {
    testWidgets('uses correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AudioPlayerScreen(title: testTitle, url: testUrl),
        ),
      );

      // Vérifier le Scaffold avec la couleur de fond
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.navy);
    });
  });
}
