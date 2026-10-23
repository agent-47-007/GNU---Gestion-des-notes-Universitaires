import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

abstract interface class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class StudentApiClient {
  StudentApiClient({
    String? baseUrl,
    http.Client? client,
    SessionStorage? storage,
    this.expectedRole = 'ETUDIANT',
  }) : baseUrl = _resolveApiBaseUrl(baseUrl),
       _client = client ?? http.Client(),
       _storage = storage ?? SecureSessionStorage();

  final String baseUrl;
  final http.Client _client;
  final SessionStorage _storage;
  final String expectedRole;
  static const _storedRoleKey = 'gnu.portal.role';
  String get _roleKey => switch (expectedRole) {
    'ENSEIGNANT' => 'teacher',
    'AGENT' => 'agent',
    _ => 'student',
  };
  String get _tokenKey => 'gnu.$_roleKey.token';
  String get _expiryKey => 'gnu.$_roleKey.expires_at';
  String get _profilePath =>
      '/profil/${_roleKey == 'student'
          ? 'etudiant'
          : _roleKey == 'teacher'
          ? 'enseignant'
          : 'agent'}';
  String? token;
  String? activeAcademicYearId;
  Map<String, dynamic>? user;
  Future<void> Function()? onUnauthorized;
  bool get isAuthenticated => token != null;

  Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {
        'login': login.trim(),
        'password': password,
        'device_name': 'GNU Web · $_roleKey',
      },
      authenticated: false,
    );
    await _storeSession(response);
    user = _map(response['utilisateur']);
    if (token == null || user?['role'] != expectedRole) {
      await clearSession();
      throw ApiFailure(
        'Ce compte ne correspond pas au profil ${_roleLabel(expectedRole)}.',
      );
    }
    return user!;
  }

  Future<bool> restoreSession() async {
    final savedToken = await _storage.read(_tokenKey);
    final expiresAt = DateTime.tryParse(
      (await _storage.read(_expiryKey)) ?? '',
    );
    if (savedToken == null ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now())) {
      await clearSession();
      return false;
    }
    token = savedToken;
    try {
      final profile = await getProfile();
      if (profile['role'] != expectedRole || profile['actif'] != true) {
        await clearSession();
        return false;
      }
      user = profile;
      return true;
    } on ApiFailure catch (error) {
      await clearSession();
      if (error.statusCode == 401 || error.statusCode == 403) return false;
      rethrow;
    }
  }

  Future<void> _storeSession(Map<String, dynamic> response) async {
    token = response['token'] as String?;
    user = _map(response['utilisateur']);
    final expiresAt = response['expires_at']?.toString();
    if (token != null && expiresAt != null) {
      await _storage.write(_tokenKey, token!);
      await _storage.write(_expiryKey, expiresAt);
      await _storage.write(_storedRoleKey, expectedRole);
    }
  }

  Future<void> clearSession() async {
    token = null;
    user = null;
    await _storage.delete(_tokenKey);
    await _storage.delete(_expiryKey);
    if (await _storage.read(_storedRoleKey) == expectedRole) {
      await _storage.delete(_storedRoleKey);
    }
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<Map<String, dynamic>> getProfile() async =>
      _map((await _send('GET', _profilePath))['data']) ?? {};

  String get _academicYearPreferenceKey =>
      'gnu.$_roleKey.${user?['id'] ?? 'session'}.academic_year';

  Future<String?> readAcademicYearPreference() =>
      _storage.read(_academicYearPreferenceKey);

  Future<void> selectAcademicYear(String id) async {
    activeAcademicYearId = id;
    await _storage.write(_academicYearPreferenceKey, id);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async =>
      _map((await _send('PUT', _profilePath, body: data))['data']) ?? {};

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _send(
      'POST',
      '/auth/password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<List<Map<String, dynamic>>> teacherAssignments() async =>
      _list((await _send('GET', '/enseignant/affectations'))['data']);

  Future<Map<String, dynamic>> teacherEvaluationPlan(int assignmentId) async =>
      _map(
        (await _send(
          'GET',
          '/enseignant/affectations/$assignmentId/plan-evaluation',
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> teacherSaveEvaluationPlan(
    int assignmentId, {
    required List<Map<String, dynamic>> evaluations,
    String reason = '',
  }) async =>
      _map(
        (await _send(
          'PUT',
          '/enseignant/affectations/$assignmentId/plan-evaluation',
          body: {'evaluations': evaluations, 'motif': reason},
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> teacherGradebook(int assignmentId) async =>
      _map(
        (await _send(
          'GET',
          '/enseignant/affectations/$assignmentId/carnet',
        ))['data'],
      ) ??
      {};

  Future<void> teacherDecideGradeTransmission(
    int transmissionId, {
    required String decision,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/enseignant/transmissions-notes/$transmissionId',
      body: {'decision': decision, 'motif': reason},
    );
  }

  Future<List<Map<String, dynamic>>> teacherProvisionalBulletins(
    int assignmentId, {
    required String period,
  }) async => _list(
    (await _send(
      'GET',
      '/enseignant/affectations/$assignmentId/bulletins-provisoires?periode=$period',
    ))['data']?['etudiants'],
  );

  Future<void> teacherUpdateEvaluationStatus(
    int assignmentId,
    int evaluationId, {
    required String status,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/enseignant/affectations/$assignmentId/evaluations/$evaluationId',
      body: {'statut_evaluation': status, 'motif': reason},
    );
  }

  Future<void> teacherSaveGrades(
    int assignmentId,
    int evaluationId, {
    required List<Map<String, dynamic>> grades,
    String reason = '',
  }) async {
    await _send(
      'PUT',
      '/enseignant/affectations/$assignmentId/evaluations/$evaluationId/notes',
      body: {'notes': grades, 'motif': reason},
    );
  }

  Future<void> teacherSaveStudentGrades(
    int assignmentId, {
    required String matricule,
    required List<Map<String, dynamic>> grades,
    String reason = '',
  }) async {
    await _send(
      'PUT',
      '/enseignant/affectations/$assignmentId/notes-etudiant',
      body: {'matricule': matricule, 'notes': grades, 'motif': reason},
    );
  }

  Future<int> teacherTransmitGrades(
    int assignmentId,
    int evaluationId, {
    String reason = '',
  }) async =>
      (_map(
                await _send(
                  'POST',
                  '/enseignant/affectations/$assignmentId/evaluations/$evaluationId/notes/transmettre',
                  body: {'motif': reason},
                ),
              )?['transmises']
              as num?)
          ?.toInt() ??
      0;

  Future<Map<String, dynamic>> teacherImportGrades(
    int assignmentId,
    int evaluationId, {
    required String filename,
    required Uint8List file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/enseignant/affectations/$assignmentId/evaluations/$evaluationId/notes/importer',
      ),
    );
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes('fichier', file, filename: filename),
    );
    return _decodeAuthenticated(
      await http.Response.fromStream(await _client.send(request)),
      true,
    );
  }

  Future<Map<String, dynamic>> teacherPreviewGradebookImport(
    int assignmentId, {
    required String filename,
    required Uint8List file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '$baseUrl/enseignant/affectations/$assignmentId/notes/importer-classe',
      ),
    );
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes('fichier', file, filename: filename),
    );
    return _decodeAuthenticated(
      await http.Response.fromStream(await _client.send(request)),
      true,
    );
  }

  Future<void> teacherRemoveGrade(
    int assignmentId,
    int noteId, {
    required int version,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/enseignant/affectations/$assignmentId/notes/$noteId/retrait',
      body: {'version_note': version, 'motif': reason},
    );
  }

  Future<List<Map<String, dynamic>>> teacherRequests() async =>
      _list((await _send('GET', '/enseignant/requetes'))['data']);

  Future<void> teacherDecideRequest(
    int requestId, {
    required String decision,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/enseignant/requetes/$requestId',
      body: {'decision': decision, 'motif': reason},
    );
  }

  Future<void> teacherCreateRetakeSession(
    int assignmentId, {
    required String label,
    required String date,
  }) async {
    await _send(
      'POST',
      '/enseignant/affectations/$assignmentId/rattrapages/sessions',
      body: {'libelle': label, 'date_session': date},
    );
  }

  Future<List<Map<String, dynamic>>> teacherRetakeCandidates(
    int assignmentId,
  ) async => _list(
    (await _send(
      'GET',
      '/enseignant/affectations/$assignmentId/rattrapages',
    ))['data'],
  );

  Future<void> teacherCreateRetakeEvaluations(
    int assignmentId,
    int sessionId,
  ) async {
    await _send(
      'POST',
      '/enseignant/affectations/$assignmentId/rattrapages/sessions/$sessionId/evaluations',
    );
  }

  Future<void> teacherSaveRetakeGrades(
    int assignmentId,
    int evaluationId, {
    required List<Map<String, dynamic>> grades,
    String reason = '',
  }) async {
    await _send(
      'PUT',
      '/enseignant/affectations/$assignmentId/rattrapages/evaluations/$evaluationId/notes',
      body: {'notes': grades, 'motif': reason},
    );
  }

  Future<Map<String, dynamic>> agentDashboard() async =>
      _map((await _send('GET', '/agent/dashboard'))['data']) ?? {};

  Future<List<Map<String, dynamic>>> agentClasses() async =>
      _list((await _send('GET', '/agent/classes'))['data']);

  Future<List<Map<String, dynamic>>> academicYears() async =>
      _list((await _send('GET', '/referentiels/annees-academiques'))['data']);

  Future<List<Map<String, dynamic>>> agentLevels() async =>
      _list((await _send('GET', '/agent/niveaux'))['data']);

  Future<Map<String, dynamic>> agentCatalog() async =>
      _map((await _send('GET', '/agent/catalogue'))['data']) ?? {};

  Future<Map<String, dynamic>> agentAcademicStructure() async =>
      _map((await _send('GET', '/agent/structure'))['data']) ?? {};

  Future<void> agentSaveAcademicStructure(
    String kind, {
    int? id,
    required Map<String, dynamic> data,
  }) async {
    final plural = switch (kind) {
      'universite' => 'universites',
      'faculte' => 'facultes',
      'departement' => 'departements',
      'filiere' => 'filieres',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    await _send(
      id == null ? 'POST' : 'PATCH',
      '/agent/structure/$plural${id == null ? '' : '/$id'}',
      body: data,
    );
  }

  Future<Map<String, dynamic>> agentPublicationRules() async =>
      _map((await _send('GET', '/agent/publication/regles'))['data']) ?? {};

  Future<void> agentApprovePublicationRules({String reason = ''}) async {
    await _send(
      'POST',
      '/agent/publication/regles/approuver',
      body: {'confirmer': true, 'motif': reason},
    );
  }

  Future<void> agentSetPublicationAuthorization(
    int userId, {
    required bool authorized,
    String reason = '',
  }) async {
    await _send(
      'PUT',
      '/agent/publication/habilitations/$userId',
      body: {'autorise': authorized, 'motif': reason},
    );
  }

  Future<void> agentCreateClass(Map<String, dynamic> data) async {
    await _send('POST', '/agent/classes', body: data);
  }

  Future<void> agentCreateUnit(Map<String, dynamic> data) async {
    await _send('POST', '/agent/ues', body: data);
  }

  Future<void> agentCreateElement(int ueId, Map<String, dynamic> data) async {
    await _send('POST', '/agent/ues/$ueId/elements', body: data);
  }

  Future<void> agentSetUnitStatus(int ueId, String status) async {
    await _send(
      'PATCH',
      '/agent/ues/$ueId/statut',
      body: {'statut_catalogue': status},
    );
  }

  Future<void> agentSetUnitEvaluationProfile(int ueId, String profile) async {
    await _send(
      'PUT',
      '/agent/ues/$ueId/profil-evaluation',
      body: {'code_profil': profile},
    );
  }

  Future<void> teacherProposeEvaluationProfile(
    int assignmentId,
    String profile,
  ) async {
    await _send(
      'POST',
      '/enseignant/affectations/$assignmentId/profil-evaluation/proposition',
      body: {'code_profil': profile},
    );
  }

  Future<List<Map<String, dynamic>>> agentAccounts() async =>
      _list((await _send('GET', '/agent/comptes'))['data']);

  Future<void> agentSetAccountStatus(
    int userId, {
    required bool active,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/agent/comptes/$userId/statut',
      body: {'actif': active, 'motif': reason},
    );
  }

  Future<void> agentUpdateAccount(int userId, Map<String, dynamic> data) async {
    await _send('PATCH', '/agent/comptes/$userId', body: data);
  }

  Future<List<Map<String, dynamic>>> agentAssignments() async =>
      _list((await _send('GET', '/agent/affectations'))['data']);

  Future<void> agentCreateAssignment(Map<String, dynamic> data) async {
    await _send('POST', '/agent/affectations', body: data);
  }

  Future<void> agentSetAssignmentStatus(int id, bool active) async {
    await _send('PATCH', '/agent/affectations/$id', body: {'actif': active});
  }

  Future<List<Map<String, dynamic>>> agentEnrollments() async =>
      _list((await _send('GET', '/agent/inscriptions?statut=SOUMISE'))['data']);

  Future<void> agentReviewEnrollment(
    int id, {
    required String decision,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/agent/inscriptions/$id',
      body: {'decision': decision, 'motif': reason},
    );
  }

  Future<Uint8List> agentDownloadAcademicSheet(int registrationId) async =>
      _downloadBytes(
        '/agent/inscriptions/$registrationId/fiche-academique',
        'Impossible de télécharger la fiche académique.',
      );

  Future<List<Map<String, dynamic>>> agentRequests() async =>
      _list((await _send('GET', '/agent/requetes'))['data']);

  Future<List<Map<String, dynamic>>> agentGradeTransmissions() async =>
      _list((await _send('GET', '/agent/notes/transmissions'))['data']);

  Future<void> agentReturnGradeTransmission(
    int transmissionId, {
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/agent/notes/transmissions/$transmissionId/retour',
      body: {'motif': reason},
    );
  }

  Future<void> agentDigitizeGradeTransmission(
    int transmissionId, {
    required List<Map<String, dynamic>> notes,
    String reason = '',
  }) async {
    await _send(
      'PUT',
      '/agent/notes/transmissions/$transmissionId/numerisation',
      body: {'notes': notes, 'motif': reason},
    );
  }

  Future<void> agentRouteRequest(
    int requestId, {
    required int teacherId,
    String reason = '',
  }) async {
    await _send(
      'PATCH',
      '/agent/requetes/$requestId/affectation',
      body: {'enseignant_id': teacherId, 'motif': reason},
    );
  }

  Future<Map<String, dynamic>> agentBulletinPreview(
    int classId,
    String period,
  ) async =>
      _map(
        (await _send(
          'GET',
          '/agent/classes/$classId/apercu-bulletins?periode=$period',
        ))['data'],
      ) ??
      {};

  Future<void> agentPublish(
    int classId,
    String period, {
    bool confirmNewVersion = false,
  }) async {
    await _send(
      'POST',
      '/agent/classes/$classId/publications',
      body: {
        'periode': period,
        'confirmer_nouvelle_version': confirmNewVersion,
      },
    );
  }

  Future<List<Map<String, dynamic>>> agentAudit() async =>
      _list((await _send('GET', '/agent/audit'))['data']);

  Future<List<Map<String, dynamic>>> agentRetakeSessions() async =>
      _list((await _send('GET', '/agent/rattrapages/sessions'))['data']);

  Future<List<Map<String, dynamic>>> agentRetakeOpportunities() async =>
      _list((await _send('GET', '/agent/rattrapages/opportunites'))['data']);

  Future<void> agentCreateRetakeSession(Map<String, dynamic> data) async {
    await _send('POST', '/agent/rattrapages/sessions', body: data);
  }

  Future<void> agentSetRetakeSessionStatus(int id, String status) async {
    await _send(
      'PATCH',
      '/agent/rattrapages/sessions/$id',
      body: {'statut_session': status},
    );
  }

  Future<Map<String, dynamic>> updateEmail(String? email) async =>
      _map(
        (await _send(
          'PUT',
          '/etudiant/profil',
          body: {'courriel': email},
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> enrollment(int semester) async =>
      _map(
        (await _send(
          'GET',
          '/etudiant/inscriptions?semestre=$semester',
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> saveEnrollment(
    int semester,
    List<String> codes,
  ) async =>
      _map(
        (await _send(
          'PUT',
          '/etudiant/inscriptions',
          body: {'semestre': semester, 'codes_ue': codes},
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> submitEnrollment(int semester) async =>
      _map(
        (await _send(
          'POST',
          '/etudiant/inscriptions/soumettre',
          body: {'semestre': semester},
        ))['data'],
      ) ??
      {};

  Future<Map<String, dynamic>> studentAcademicSheet() async =>
      _map((await _send('GET', '/etudiant/fiche-academique'))['data']) ?? {};

  Future<Map<String, dynamic>> uploadStudentAcademicSheet({
    required String filename,
    required Uint8List file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/etudiant/fiche-academique'),
    );
    request.headers.addAll(_headers());
    request.files.add(
      http.MultipartFile.fromBytes('fiche', file, filename: filename),
    );
    final streamed = await _client.send(request);
    return _decodeAuthenticated(await http.Response.fromStream(streamed), true);
  }

  Future<Uint8List> downloadStudentAcademicSheet() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/etudiant/fiche-academique/fichier'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await clearSession();
        await onUnauthorized?.call();
      }
      throw ApiFailure(
        'Impossible de consulter la fiche académique importée.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<Uint8List> teacherDownloadAcademicSheet({
    required int assignmentId,
    required int registrationId,
  }) async => _downloadBytes(
    '/enseignant/affectations/$assignmentId/inscriptions/$registrationId/fiche-academique',
    'Impossible de télécharger la fiche académique.',
  );

  Future<Uint8List> _downloadBytes(String path, String errorMessage) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await clearSession();
        await onUnauthorized?.call();
      }
      throw ApiFailure(errorMessage, statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  Future<List<Map<String, dynamic>>> results({String? period}) async => _list(
    (await _send(
      'GET',
      '/etudiant/resultats${period == null ? '' : '?periode=$period'}',
    ))['data'],
  );

  Future<Map<String, dynamic>> provisionalResults({
    String period = 'S1',
  }) async =>
      _map(
        (await _send(
          'GET',
          '/etudiant/resultats/provisoires?periode=$period',
        ))['data'],
      ) ??
      {};

  Future<List<Map<String, dynamic>>> requests() async =>
      _list((await _send('GET', '/etudiant/requetes'))['data']);

  Future<List<Map<String, dynamic>>> missingEvaluations({
    required String code,
    required String codeM,
  }) async => _list(
    (await _send(
      'GET',
      '/etudiant/evaluations-manquantes?code_ue=${Uri.encodeQueryComponent(code)}&code_m=${Uri.encodeQueryComponent(codeM)}',
    ))['data'],
  );

  Future<void> createRequest({
    required String code,
    required String codeM,
    required String type,
    required String message,
    int? evaluationId,
    String? filename,
    Uint8List? file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/etudiant/requetes'),
    );
    request.headers.addAll(_headers());
    request.fields.addAll({
      'code_ue': code,
      'code_m': codeM,
      'type': type,
      'message': message,
      if (evaluationId != null) 'evaluation_id': evaluationId.toString(),
    });
    if (filename != null && file != null) {
      request.files.add(
        http.MultipartFile.fromBytes('justificatif', file, filename: filename),
      );
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    await _decodeAuthenticated(response, true);
  }

  Future<List<Map<String, dynamic>>> retakes() async =>
      _list((await _send('GET', '/etudiant/rattrapages'))['data']);

  Future<void> applyForRetake({
    required String unitCode,
    required int sessionId,
  }) async {
    await _send(
      'POST',
      '/etudiant/rattrapages/candidatures',
      body: {'code_ue': unitCode, 'session_id': sessionId},
    );
  }

  Future<List<Map<String, dynamic>>> notifications() async =>
      _list((await _send('GET', '/etudiant/notifications'))['data']);

  Future<void> markNotificationRead(int id) async =>
      _send('PATCH', '/etudiant/notifications/$id/lue');

  Future<Uint8List> downloadRequestProof(int id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/etudiant/requetes/$id/justificatif'),
      headers: _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await clearSession();
        await onUnauthorized?.call();
      }
      throw ApiFailure(
        'Impossible de télécharger le justificatif.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (activeAcademicYearId != null &&
        !path.startsWith('/referentiels/annees-academiques')) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'annee_id': activeAcademicYearId!,
        },
      );
    }
    final request = http.Request(method, uri)
      ..headers.addAll(_headers(authenticated: authenticated));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final streamed = await _client.send(request);
    return _decodeAuthenticated(
      await http.Response.fromStream(streamed),
      authenticated,
    );
  }

  Future<Map<String, dynamic>> _decodeAuthenticated(
    http.Response response,
    bool authenticated,
  ) async {
    try {
      return _decode(response);
    } on ApiFailure catch (error) {
      if (authenticated && error.statusCode == 401) {
        await clearSession();
        await onUnauthorized?.call();
      }
      rethrow;
    }
  }

  Map<String, String> _headers({bool authenticated = true}) => {
    'Accept': 'application/json',
    if (authenticated && token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : _map(jsonDecode(response.body)) ?? <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = body['errors'];
      Object? firstError;
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            firstError = value.first;
            break;
          }
        }
      }
      throw ApiFailure(
        (firstError ?? body['message'] ?? 'La requête au serveur a échoué.')
            .toString(),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Map<String, dynamic>? _map(Object? value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : null;

  List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.map(_map).whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];

  void dispose() => _client.close();
}

String _roleLabel(String role) => switch (role) {
  'ENSEIGNANT' => 'enseignant',
  'AGENT' => 'agent de la cellule informatique',
  _ => 'étudiant',
};

String _resolveApiBaseUrl(String? override) {
  final configured =
      (override ?? const String.fromEnvironment('GNU_API_BASE_URL')).trim();
  if (configured.isEmpty) {
    if (kReleaseMode) {
      throw const ApiFailure(
        'GNU_API_BASE_URL doit être définie pour une version de production.',
      );
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  final normalized = configured.replaceFirst(RegExp(r'/$'), '');
  final uri = Uri.tryParse(normalized);
  if (kReleaseMode &&
      (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          const ['localhost', '127.0.0.1', '::1'].contains(uri.host) ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.path.replaceFirst(RegExp(r'/+$'), '') != '/api/v1')) {
    throw const ApiFailure(
      'GNU_API_BASE_URL doit être une URL HTTPS valide terminée par /api/v1.',
    );
  }

  return normalized;
}
