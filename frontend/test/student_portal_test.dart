import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/api_client.dart';
import 'package:gnu_frontend/student_portal.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('session expirée au démarrage est effacée sans requête', () async {
    final storage = _TestSessionStorage()
      ..values['gnu.student.token'] = 'expired-token'
      ..values['gnu.student.expires_at'] = DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String();
    final api = StudentApiClient(storage: storage);
    addTearDown(api.dispose);
    expect(await api.restoreSession(), isFalse);
    expect(api.isAuthenticated, isFalse);
    expect(storage.values, isEmpty);
  });

  test('révocation serveur efface le jeton et notifie la racine', () async {
    final storage = _TestSessionStorage()
      ..values['gnu.student.token'] = 'revoked-token'
      ..values['gnu.student.expires_at'] = DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String();
    final api = StudentApiClient(
      baseUrl: 'http://gnu.test/api/v1',
      storage: storage,
      client: MockClient(
        (_) async => http.Response('{"message":"Unauthenticated."}', 401),
      ),
    )..token = 'revoked-token';
    var expired = 0;
    api.onUnauthorized = () async {
      expired++;
    };
    addTearDown(api.dispose);
    await expectLater(api.results(), throwsA(isA<ApiFailure>()));
    expect(storage.values, isEmpty);
    expect(api.isAuthenticated, isFalse);
    expect(expired, 1);
  });

  testWidgets('profil étudiant enregistre le courriel via l’API', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    var profileReads = 0;
    final api = _api((request) {
      requests.add(request);
      if (request.url.path == '/api/v1/etudiant/fiche-academique') {
        return _json({'data': {'available': false}});
      }
      if (request.url.path == '/api/v1/etudiant/inscriptions') {
        return _json({'data': _enrollment});
      }
      if (request.url.path == '/api/v1/profil/etudiant') {
        if (request.method == 'GET') {
          profileReads++;
        }
        return _json({
          'data': {
            ..._profile,
            if (request.method == 'PUT' || profileReads > 1)
              'courriel': 'nouveau@example.test'
            else
              'courriel': 'ancien@example.test',
          },
        });
      }
      return _json({'data': <Object>[]});
    });
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: Scaffold(
          body: LiveStudentPage(page: 'profile', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Informations personnelles'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.keyboardType == TextInputType.emailAddress,
      ),
      'nouveau@example.test',
    );
    await tester.tap(find.text('Enregistrer le profil'));
    await tester.pumpAndSettle();

    final update = requests.singleWhere(
      (request) =>
          request.method == 'PUT' &&
          request.url.path == '/api/v1/profil/etudiant',
    );
    expect(update.method, 'PUT');
    expect((jsonDecode(update.body) as Map)['courriel'], 'nouveau@example.test');
    expect(find.text('Profil enregistré.'), findsOneWidget);
  });

  testWidgets('inscription semestrielle peut être soumise et remplacée', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    final api = _api((request) {
      requests.add(request);
      if (request.url.path == '/api/v1/etudiant/inscriptions') {
        return _json({'data': _enrollment});
      }
      return _json({'data': _enrollment});
    });
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveStudentPage(page: 'enrollment', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INF211 · PROGRAMMATION ORIENTÉE OBJET'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soumettre les choix'));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'PUT' &&
            request.url.path == '/api/v1/etudiant/inscriptions' &&
            ((jsonDecode(request.body) as Map)['codes_ue'] as List).contains(
              'INF211',
            ),
      ),
      isTrue,
    );
    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/api/v1/etudiant/inscriptions/soumettre',
      ),
      isTrue,
    );
    expect(find.text('Soumettre les choix'), findsOneWidget);
  });

  testWidgets('rattrapage admissible s’affiche sous 50 sur 100', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _api((request) {
      if (request.url.path == '/api/v1/etudiant/rattrapages') {
        return _json({
          'data': [
            {
              'code_ue': 'INF212',
              'intitule': 'MATHEMATIQUES DISCRETES',
              'note_sur_100': 49,
              'eligible': true,
              'statut': 'ELIGIBLE',
            },
          ],
        });
      }
      return _json({'data': <Object>[]});
    });
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveStudentPage(page: 'retakes', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('INF212 · MATHEMATIQUES DISCRETES'),
      findsOneWidget,
    );
    expect(find.textContaining('Note : —/20'), findsOneWidget);
  });
}

class _TestSessionStorage implements SessionStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

StudentApiClient _api(http.Response Function(http.Request) handler) {
  final api = StudentApiClient(
    baseUrl: 'http://gnu.test/api/v1',
    client: MockClient((request) async => handler(request)),
  )..token = 'test-token';
  return api;
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

const _profile = <String, Object>{
  'id': 3,
  'login': 'etudiant',
  'role': 'ETUDIANT',
  'nom': 'Ngue Mbong',
  'prenom': 'André Fitzgerald',
  'courriel': 'ancien@example.test',
  'profil': {'matricule': '21T2355'},
};

const _enrollment = <String, Object>{
  'inscription_classe_id': 25,
  'classe': 'INF-L3-2025-2026',
  'annee_academique': '2025-2026',
  'statut': 'BROUILLON',
  'semestre': 1,
  'peut_modifier': true,
  'nombre_ue_attendu': 1,
  'nombre_ue_disponible': 1,
  'unites': [
    {
      'id': 1,
      'code': 'INF211',
      'intitule': 'PROGRAMMATION ORIENTÉE OBJET',
      'credits': 6,
      'obligatoire': true,
      'selectionnee': false,
      'enseignants': ['Jean Kouam'],
      'ponderation_libelle': 'CC 30% · TP 0% · SN 70%',
    },
  ],
};
