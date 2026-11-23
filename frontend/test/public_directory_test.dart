import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/api_client.dart';
import 'package:gnu_frontend/public_directory.dart';
import 'package:gnu_frontend/ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('annuaire public à $width pixels sans connexion', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <Uri>[];
      var signIns = 0;
      final api = StudentApiClient(
        baseUrl: 'https://gnu.test/api/v1',
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'nom': 'Université de Yaoundé I',
                  'categorie': 'UNIVERSITE_PUBLIQUE',
                  'region': 'Centre',
                  'ville': 'Yaoundé',
                },
              ],
              'regions': ['Centre'],
              'statistiques': [
                {'categorie': 'UNIVERSITE_PUBLIQUE', 'nombre': 11},
              ],
              'pagination': {'page': 1, 'pages': 1, 'total': 1},
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: PublicDirectoryPage(api: api, onSignIn: () => signIns++),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Université de Yaoundé I'), findsOneWidget);
      expect(signIns, 0);
      expect(requests.single.path, '/api/v1/public/institutions');
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Douala');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['q'], 'Douala');
      await tester.tap(find.text('Espace académique'));
      expect(signIns, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('annuaire indisponible conserve accès au portail', (
    tester,
  ) async {
    final api = StudentApiClient(
      baseUrl: 'https://gnu.test/api/v1',
      client: MockClient(
        (_) async => http.Response('{"message":"Indisponible"}', 503),
      ),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PublicDirectoryPage(api: api, onSignIn: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('L’annuaire est temporairement indisponible.'),
      findsOneWidget,
    );
    expect(find.text('Espace académique'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('fiche publique affiche cursus, niveaux et source annuelle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = StudentApiClient(
      baseUrl: 'https://gnu.test/api/v1',
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        if (request.url.path.endsWith('/1')) {
          return http.Response(
            jsonEncode({
              'data': {
                'institution': {
                  'nom': 'UY1',
                  'categorie': 'UNIVERSITE_PUBLIQUE',
                  'source_url': 'https://uy1.uninet.cm/',
                  'consulte_le': '2026-11-23',
                },
                'information': 'Catalogue sourcé',
                'etablissements': [
                  {
                    'nom_fac': 'Faculté des Sciences',
                    'departements': [
                      {
                        'nom_depart': 'Informatique',
                        'filieres': [
                          {
                            'nom_f': 'Master SIGL',
                            'niveaux': [
                              {'libelle_niv': 'Master 1'},
                            ],
                            'sources': [
                              {
                                'source_url': 'https://uy1.uninet.cm/wp-content/uploads/2026/08/tableau-officiel.jpg',
                                'annee_source': '2026-2027',
                                'source_date': '2026-07-31',
                                'consulte_le': '2026-11-23',
                                'details': {
                                  'methode_niveaux':
                                      'Entrée en Master 1 publiée',
                                },
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 1, 'nom': 'UY1', 'categorie': 'UNIVERSITE_PUBLIQUE'},
            ],
            'pagination': {'page': 1, 'pages': 1, 'total': 1},
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: PublicDirectoryPage(api: api, onSignIn: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Voir la vitrine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir la vitrine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Faculté des Sciences'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Informatique'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informatique'));
    await tester.pumpAndSettle();
    expect(find.text('Master SIGL'), findsOneWidget);
    expect(find.text('Master 1'), findsOneWidget);
    expect(find.text('Source pour l’année 2026–2027'), findsOneWidget);
    expect(find.text('Document du 2026-07-31'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
