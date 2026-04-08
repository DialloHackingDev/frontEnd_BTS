import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/library/screens/library_screen.dart';

/// Tests simplifiés pour LibraryScreen
/// Ces tests vérifient l'UI sans mocking complexe
void main() {
  group('LibraryScreen UI Tests', () {
    testWidgets('renders app bar with correct title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier le titre de l'AppBar
      expect(find.text('BORN TO SUCCESS'), findsOneWidget);
    });

    testWidgets('renders search bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier la barre de recherche
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders filter chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier les filtres
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Vidéo'), findsOneWidget);
    });

    testWidgets('renders refresh button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier le bouton refresh
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('renders cache management button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier le bouton de gestion du cache
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    });

    testWidgets('search bar has correct hint text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Vérifier le texte d'indication
      expect(find.text('Rechercher une ressource...'), findsOneWidget);
    });

    testWidgets('filter chips are tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Tap sur le filtre PDF
      await tester.tap(find.text('PDF'));
      await tester.pump();

      // Tap sur le filtre Audio
      await tester.tap(find.text('Audio'));
      await tester.pump();

      // Tap sur le filtre Vidéo
      await tester.tap(find.text('Vidéo'));
      await tester.pump();

      // Les taps ne doivent pas provoquer d'erreurs
      expect(find.text('PDF'), findsOneWidget);
    });
  });

  group('LibraryScreen Loading States', () {
    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );

      // Au démarrage, un indicateur de chargement doit être présent
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('LibraryScreen Error States', () {
    testWidgets('renders correctly with MaterialApp scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const LibraryScreen(),
        ),
      );

      // Vérifier que le Scaffold est rendu
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
