import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'agent_portal.dart';
import 'public_directory.dart';
import 'api_client.dart';
import 'domain.dart';
import 'ui.dart';
import 'pages.dart';
import 'student_portal.dart';
import 'teacher_portal.dart';
import 'local_portal_navigation.dart';

const _compiledApiBaseUrl = String.fromEnvironment('GNU_API_BASE_URL');

List<int>? _ipv4Octets(String host) {
  final octets = host.split('.').map(int.tryParse).toList();
  if (octets.length != 4 ||
      octets.any((octet) => octet == null || octet < 0 || octet > 255)) {
    return null;
  }

  return octets.cast<int>();
}

bool _isLoopbackHost(String host) {
  final normalizedHost = host.toLowerCase();
  if (const ['localhost', '::1'].contains(normalizedHost)) return true;

  final octets = _ipv4Octets(normalizedHost);
  return octets != null && octets[0] == 127;
}

bool _isPrivateLanHost(String host) {
  final octets = _ipv4Octets(host);
  if (octets == null) return false;

  final first = octets[0];
  final second = octets[1];

  return first == 10 ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

String? _localTestPortalHost(Uri apiUri, Uri pageUri) {
  var host = apiUri.host;
  if (host == '0.0.0.0' || host == '::') {
    host = _isPrivateLanHost(pageUri.host) ? pageUri.host : '127.0.0.1';
  } else if (_isLoopbackHost(host) && _isPrivateLanHost(pageUri.host)) {
    host = pageUri.host;
  }

  return _isLoopbackHost(host) || _isPrivateLanHost(host) ? host : null;
}

bool _releaseApiUrlIsValid() {
  if (!kReleaseMode) return true;
  final uri = Uri.tryParse(_compiledApiBaseUrl.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !const ['localhost', '127.0.0.1', '::1'].contains(uri.host) &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      uri.path.replaceFirst(RegExp(r'/+$'), '') == '/api/v1';
}

void main() => runApp(
  _releaseApiUrlIsValid()
      ? const GnuApp()
      : const ProductionConfigurationRequiredApp(),
);

class ProductionConfigurationRequiredApp extends StatelessWidget {
  const ProductionConfigurationRequiredApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GNU · Configuration requise',
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuration de production requise',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 16),
                Text(
                  'Cette version ne peut pas se connecter au serveur GNU. '
                  'Recompilez-la avec GNU_API_BASE_URL défini sur l’URL HTTPS '
                  'de l’API se terminant par /api/v1.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class GnuApp extends StatefulWidget {
  const GnuApp({super.key, this.sessionStorage});
  final SessionStorage? sessionStorage;
  @override
  State<GnuApp> createState() => _GnuAppState();
}

class _GnuAppState extends State<GnuApp> {
  final store = DemoStore();
  UserRole? role;
  bool showLogin = false;
  StudentApiClient? directoryApi;
  bool darkMode = false;
  StudentApiClient? liveStudentApi;

  StudentApiClient _roleClient(UserRole role, String apiBaseUrl) {
    final client = StudentApiClient(
      baseUrl: apiBaseUrl,
      storage: widget.sessionStorage,
      expectedRole: _apiRole(role),
    );
    client.onUnauthorized = () async {
      if (mounted && identical(liveStudentApi, client)) {
        setState(() {
          liveStudentApi = null;
          this.role = null;
        });
        client.dispose();
      }
    };
    return client;
  }

  @override
  void dispose() {
    directoryApi?.dispose();
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GNU · Campus numérique',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    darkTheme: buildTheme(dark: true),
    themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    home: role == null
        ? showLogin
              ? WelcomePage(
                  onRoleLogin: _loginRole,
                  onBrowseDirectory: () => setState(() => showLogin = false),
                )
              : PublicDirectoryPage(
                  api: directoryApi ??= StudentApiClient(
                    baseUrl: _compiledApiBaseUrl.isNotEmpty
                        ? _compiledApiBaseUrl
                        : kIsWeb
                        ? Uri.base.resolve('/api/v1').toString()
                        : 'http://127.0.0.1:8000/api/v1',
                  ),
                  onSignIn: () => setState(() => showLogin = true),
                )
        : Portal(
            key: ValueKey(role),
            role: role!,
            store: store,
            onExit: _exitPortal,
            apiClient: liveStudentApi,
            darkMode: darkMode,
            onToggleTheme: () => setState(() => darkMode = !darkMode),
          ),
  );

  Future<void> _loginRole(
    UserRole selectedRole,
    String login,
    String password,
    String apiBaseUrl,
  ) async {
    final client = _roleClient(selectedRole, apiBaseUrl);
    try {
      await client.login(login, password);
      if (!mounted) {
        client.dispose();
        return;
      }
      setState(() {
        liveStudentApi = client;
        role = selectedRole;
      });
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  void _exitPortal() {
    final client = liveStudentApi;
    setState(() {
      role = null;
      liveStudentApi = null;
    });
    if (client != null) {
      unawaited(
        client.logout().catchError((_) {}).whenComplete(client.dispose),
      );
    }
  }
}

String _apiRole(UserRole role) => switch (role) {
  UserRole.student => 'ETUDIANT',
  UserRole.teacher => 'ENSEIGNANT',
  UserRole.agent => 'AGENT',
};

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.onRoleLogin,
    this.accountApiFactory,
    this.onBrowseDirectory,
  });
  final StudentApiClient Function()? accountApiFactory;
  final VoidCallback? onBrowseDirectory;
  final Future<void> Function(
    UserRole role,
    String login,
    String password,
    String apiBaseUrl,
  )
  onRoleLogin;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  UserRole selectedRole = UserRole.student;
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  late final TextEditingController apiBaseUrlController;
  bool showPassword = false;
  bool loggingIn = false;
  bool registrationLoading = false;
  bool registrationSending = false;
  String? registrationError;
  String? loginError;
  String? registrationNotice;
  Map<String, dynamic>? registrationStructure;
  final registrationFormKey = GlobalKey<FormState>();
  final registrationControllers = List.generate(
    8,
    (_) => TextEditingController(),
  );
  int? registrationUniversityId;
  int? registrationFacultyId;
  int? registrationLevelId;
  int? registrationDepartmentId;
  int? registrationProgramId;
  int? registrationSpecialtyId;
  int? registrationYearId;
  int? registrationClassId;

  bool get _needsNativeApiAddress =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get _apiBaseUrl {
    final value = apiBaseUrlController.text.trim();
    if (value.isNotEmpty) return value;
    if (_compiledApiBaseUrl.isNotEmpty) return _compiledApiBaseUrl;
    return _needsNativeApiAddress
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://127.0.0.1:8000/api/v1';
  }

  @override
  void initState() {
    super.initState();
    apiBaseUrlController = TextEditingController(
      text: _needsNativeApiAddress
          ? 'http://10.0.2.2:8000/api/v1'
          : _compiledApiBaseUrl,
    );
  }

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    apiBaseUrlController.dispose();
    for (final controller in registrationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (loggingIn) return;
    setState(() {
      loggingIn = true;
      loginError = null;
      registrationNotice = null;
    });
    try {
      await widget.onRoleLogin(
        selectedRole,
        loginController.text,
        passwordController.text,
        _apiBaseUrl,
      );
    } catch (error) {
      if (mounted) setState(() => loginError = error.toString());
    } finally {
      if (mounted) setState(() => loggingIn = false);
    }
  }

  Future<void> _requestAccount() async {
    final api =
        widget.accountApiFactory?.call() ??
        StudentApiClient(
          baseUrl: _apiBaseUrl,
          expectedRole: _apiRole(selectedRole),
        );
    setState(() {
      registrationLoading = true;
      registrationError = null;
      registrationNotice = null;
    });
    try {
      final structure = await api.accountRequestStructure();
      final departments = (structure['departements'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final programs = (structure['filieres'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final specialities = (structure['specialites'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final years = (structure['annees'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final classes = (structure['classes'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (departments.isEmpty) {
        setState(
          () => loginError =
              'Aucun département n’est disponible pour créer un compte.',
        );
        return;
      }
      final departmentId =
          registrationDepartmentId != null &&
              departments.any((item) => item['id'] == registrationDepartmentId)
          ? registrationDepartmentId
          : null;
      final programId =
          registrationProgramId != null &&
              programs.any(
                (item) =>
                    item['id'] == registrationProgramId &&
                    item['departement_id'] == departmentId,
              )
          ? registrationProgramId
          : null;
      final specialtyId =
          registrationSpecialtyId != null &&
              specialities.any(
                (item) =>
                    item['id'] == registrationSpecialtyId &&
                    item['filiere_id'] == programId,
              )
          ? registrationSpecialtyId
          : null;
      final yearId = years.isEmpty ? null : years.first['id'] as int;
      final classId =
          registrationClassId != null &&
              classes.any(
                (item) =>
                    item['id'] == registrationClassId &&
                    item['annee_id'] == yearId &&
                    item['departement_id'] == departmentId,
              )
          ? registrationClassId
          : null;
      setState(() {
        registrationStructure = structure;
        registrationDepartmentId = departmentId;
        registrationProgramId = programId;
        registrationSpecialtyId = specialtyId;
        registrationYearId = yearId;
        registrationClassId = classId;
        loginError = null;
      });
    } catch (exception) {
      if (mounted) setState(() => registrationError = exception.toString());
    } finally {
      api.dispose();
      if (mounted) setState(() => registrationLoading = false);
    }
  }

  Future<void> _submitAccountRegistration() async {
    if (registrationStructure == null) return;
    if (registrationError != null) {
      setState(() => registrationError = null);
    }
    if (!(registrationFormKey.currentState?.validate() ?? false)) return;
    final registrationClasses =
        (registrationStructure!['classes'] as List? ?? [])
            .cast<Map<String, dynamic>>();
    final requestedClass = selectedRole == UserRole.student
        ? registrationClasses.firstWhere(
            (item) => item['id'] == registrationClassId,
          )
        : null;
    final requestedTrackId = switch (selectedRole) {
      UserRole.student => requestedClass?['filiere_id'],
      UserRole.teacher => registrationProgramId,
      UserRole.agent => null,
    };
    final requestedSpecialtyId = switch (selectedRole) {
      UserRole.student => requestedClass?['specialite_id'],
      UserRole.teacher => registrationSpecialtyId,
      UserRole.agent => null,
    };
    final api =
        widget.accountApiFactory?.call() ??
        StudentApiClient(
          baseUrl: _apiBaseUrl,
          expectedRole: _apiRole(selectedRole),
        );
    setState(() {
      registrationSending = true;
      registrationError = null;
    });
    try {
      await api.submitAccountRequest({
        'role': _apiRole(selectedRole),
        'nom': registrationControllers[0].text,
        'prenom': registrationControllers[1].text,
        'login': registrationControllers[2].text,
        'identifiant_profil': registrationControllers[3].text,
        'courriel': registrationControllers[4].text,
        'departement_id': registrationDepartmentId,
        'annee_id': selectedRole == UserRole.student
            ? registrationYearId
            : null,
        'classe_id': selectedRole == UserRole.student
            ? registrationClassId
            : null,
        'filiere_id': requestedTrackId,
        'specialite_id': requestedSpecialtyId,
        'reference_identite': registrationControllers[5].text,
        'password': registrationControllers[6].text,
        'password_confirmation': registrationControllers[7].text,
      });
      if (!mounted) return;
      for (final controller in registrationControllers) {
        controller.clear();
      }
      setState(() {
        registrationStructure = null;
        registrationDepartmentId = null;
        registrationProgramId = null;
        registrationSpecialtyId = null;
        registrationYearId = null;
        registrationClassId = null;
        registrationNotice = switch (selectedRole) {
          UserRole.student => 'Votre demande et la classe choisie ont été reçues. Après approbation, votre compte et votre inscription de classe seront activés.',
          UserRole.teacher => 'Votre demande de compte enseignant a été reçue. L’administration vérifiera votre identité et votre rattachement avant activation.',
          UserRole.agent => 'Votre demande d’accès agent a été reçue. Un administrateur vérifiera votre identité et votre service avant activation.',
        };
        registrationError = null;
      });
    } catch (exception) {
      if (mounted) setState(() => registrationError = exception.toString());
    } finally {
      api.dispose();
      if (mounted) setState(() => registrationSending = false);
    }
  }

  void _selectRegistrationRole(UserRole role) {
    if (selectedRole == role) return;
    setState(() {
      selectedRole = role;
      registrationControllers[3].clear();
      registrationProgramId = null;
      registrationSpecialtyId = null;
      registrationYearId =
          ((registrationStructure?['annees'] as List?)?.firstOrNull
                  as Map?)?['id']
              as int?;
      registrationLevelId = null;
      registrationClassId = null;
      registrationError = null;
      registrationNotice = null;
    });
  }

  String? _validateRequiredField(String? value, String label, {int max = 120}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Renseignez $label.';
    if (text.runes.length > max)
      return '$label ne peut pas dépasser $max caractères.';

    return null;
  }

  String? _validateLogin(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Choisissez votre identifiant de connexion.';
    if (text.runes.length > 64)
      return 'L’identifiant est limité à 64 caractères.';
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(text)) {
      return 'Utilisez uniquement des lettres, chiffres, points, tirets et tirets bas.';
    }

    return null;
  }

  String? _validateProfileIdentifier(String? value) {
    final text = (value ?? '').trim();
    final label = switch (selectedRole) {
      UserRole.student => 'Le matricule',
      UserRole.teacher => 'L’identifiant enseignant',
      UserRole.agent => 'L’identifiant agent',
    };
    if (text.isEmpty) return 'Renseignez ${label.toLowerCase()}.';
    if (text.runes.length > 59)
      return '$label ne peut pas dépasser 59 caractères.';
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(text)) {
      return 'Utilisez uniquement des lettres, chiffres et tirets.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.runes.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Saisissez une adresse courriel valide, ou laissez le champ vide.';
    }

    return null;
  }

  String? _validateIdentityReference(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Saisissez le numéro ou la référence de la pièce.';
    if (text.runes.length < 4)
      return 'La référence doit contenir au moins 4 caractères.';
    if (text.runes.length > 160)
      return 'La référence est limitée à 160 caractères.';

    return null;
  }

  String? _validateRegistrationPassword(String? value) {
    final length = (value ?? '').runes.length;
    if (length == 0)
      return 'Saisissez un mot de passe de 12 caractères minimum.';
    if (length < 12)
      return 'Ajoutez encore ${12 - length} caractère(s) pour atteindre 12.';

    return null;
  }

  String? _validatePasswordConfirmation(String? value) {
    if ((value ?? '').isEmpty) return 'Retapez le même mot de passe.';
    if (value != registrationControllers[6].text)
      return 'Les deux mots de passe ne correspondent pas.';

    return null;
  }

  Widget _registrationForm() {
    final structure = registrationStructure;
    if (structure == null) return const SizedBox.shrink();
    final departments = (structure['departements'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final programs = (structure['filieres'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final specialities = (structure['specialites'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final years = (structure['annees'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final classes = (structure['classes'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final universities = (structure['universites'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final faculties = (structure['etablissements'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where(
          (f) =>
              universities.isEmpty ||
              f['universite_id'] == registrationUniversityId,
        )
        .toList();
    final visibleDepartments = departments
        .where((d) => d['faculte_id'] == registrationFacultyId)
        .toList();
    final departmentId = registrationDepartmentId;
    final programId = registrationProgramId;
    final isBusy = registrationSending;
    final requestedClasses = classes
        .where(
          (item) =>
              item['annee_id'] == registrationYearId &&
              item['departement_id'] == departmentId &&
              item['filiere_id'] == registrationProgramId &&
              item['niveau_id'] == registrationLevelId,
        )
        .toList();
    final identityReady =
        _validateRequiredField(registrationControllers[0].text, 'votre nom') ==
            null &&
        _validateRequiredField(
              registrationControllers[1].text,
              'votre prénom',
            ) ==
            null &&
        _validateIdentityReference(registrationControllers[5].text) == null;
    final academicReady = switch (selectedRole) {
      UserRole.student =>
        departmentId != null &&
            registrationYearId != null &&
            registrationClassId != null,
      UserRole.teacher => departmentId != null,
      UserRole.agent => departmentId != null,
    };
    final accountReady =
        _validateLogin(registrationControllers[2].text) == null &&
        _validateProfileIdentifier(registrationControllers[3].text) == null &&
        _validateEmail(registrationControllers[4].text) == null &&
        _validateRegistrationPassword(registrationControllers[6].text) ==
            null &&
        _validatePasswordConfirmation(registrationControllers[7].text) == null;
    final completedSteps = [
      identityReady,
      academicReady,
      accountReady,
    ].where((ready) => ready).length;
    final referenceLength = registrationControllers[5].text.trim().runes.length;
    final passwordLength = registrationControllers[6].text.runes.length;
    final showsAcademicPath = selectedRole == UserRole.teacher;
    final academicPathAvailable =
        showsAcademicPath &&
        programs.any((item) => item['departement_id'] == departmentId);
    final roleTitle = switch (selectedRole) {
      UserRole.student => 'Demande de compte étudiant',
      UserRole.teacher => 'Demande de compte enseignant',
      UserRole.agent => 'Demande d’accès agent',
    };
    final roleDescription = switch (selectedRole) {
      UserRole.student => 'Choisissez le département, l’année académique et la classe demandés. L’inscription à cette classe sera créée après approbation administrative.',
      UserRole.teacher => 'Indiquez votre département et, si vous le connaissez, votre domaine d’enseignement. Vos UE et classes seront attribuées par l’administration après validation.',
      UserRole.agent => 'Indiquez le département où vous exercez. Les droits d’administration système sont attribués séparément par un administrateur.',
    };
    final affiliationTitle = switch (selectedRole) {
      UserRole.student => '2 · Année et classe demandées',
      UserRole.teacher => '2 · Votre rattachement enseignant',
      UserRole.agent => '2 · Votre service administratif',
    };
    const programLabel = 'Filière / domaine d’enseignement (facultatif)';
    const specialtyLabel = 'Spécialité d’enseignement (facultative)';
    final roleGuidance = switch (selectedRole) {
      UserRole.student => 'Après vérification, l’approbation de la demande créera aussi votre inscription à cette classe.',
      UserRole.teacher => 'Ce choix aide à orienter votre demande; il ne crée pas d’affectation pédagogique.',
      UserRole.agent => 'Le département sélectionné détermine votre rattachement initial; il ne donne pas automatiquement les droits de publication.',
    };
    final profileLabel = switch (selectedRole) {
      UserRole.student => 'Matricule étudiant',
      UserRole.teacher => 'Identifiant enseignant',
      UserRole.agent => 'Identifiant professionnel',
    };
    final profileHint = switch (selectedRole) {
      UserRole.student =>
        'Saisissez le matricule communiqué par l’établissement.',
      UserRole.teacher =>
        'Saisissez votre matricule ou identifiant enseignant officiel.',
      UserRole.agent =>
        'Saisissez votre matricule ou identifiant professionnel.',
    };
    final accountSectionTitle = switch (selectedRole) {
      UserRole.student => '3 · Création de votre compte étudiant',
      UserRole.teacher => '3 · Création de votre compte enseignant',
      UserRole.agent => '3 · Création de votre compte agent',
    };
    final submitLabel = switch (selectedRole) {
      UserRole.student => 'Envoyer ma demande d’inscription',
      UserRole.teacher => 'Envoyer ma demande enseignant',
      UserRole.agent => 'Envoyer ma demande d’accès',
    };
    final affiliationPrompt = switch (selectedRole) {
      UserRole.student =>
        departmentId == null
            ? 'Choisissez votre département.'
            : registrationYearId == null
            ? 'Choisissez l’année académique demandée.'
            : registrationClassId == null
            ? 'Choisissez la classe dans laquelle vous demandez l’inscription.'
            : 'Votre rattachement est renseigné.',
      UserRole.teacher => 'Choisissez votre département de rattachement.',
      UserRole.agent => 'Choisissez votre département de rattachement.',
    };
    InputDecoration field(String label, IconData icon) =>
        InputDecoration(labelText: label, prefixIcon: Icon(icon));
    Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    Widget stepBadge(String label, bool complete) => Chip(
      avatar: Icon(
        complete ? Icons.check_circle : Icons.circle_outlined,
        size: 17,
        color: complete ? Theme.of(context).colorScheme.primary : null,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
    return Card(
      margin: const EdgeInsets.only(top: 18),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: registrationFormKey,
          autovalidateMode: AutovalidateMode.disabled,
          onChanged: () => setState(() => registrationError = null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                roleTitle,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                roleDescription,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Progression de votre demande'),
                        ),
                        Text('$completedSteps / 3'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: completedSteps / 3),
                    const SizedBox(height: 8),
                    Text(
                      completedSteps == 3
                          ? 'Tout est prêt. Vous pouvez envoyer votre demande.'
                          : !identityReady
                          ? 'Complétez vos nom, prénom et référence de pièce d’identité.'
                          : !academicReady
                          ? affiliationPrompt
                          : 'Complétez vos identifiants et sécurisez votre compte.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        stepBadge('Identité', identityReady),
                        stepBadge('Rattachement', academicReady),
                        stepBadge('Compte', accountReady),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              sectionTitle('1 · Votre identité'),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[0],
                textCapitalization: TextCapitalization.words,
                decoration: field('Nom', Icons.badge_outlined),
                validator: (value) =>
                    _validateRequiredField(value, 'votre nom'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[1],
                textCapitalization: TextCapitalization.words,
                decoration: field('Prénom(s)', Icons.person_outline),
                validator: (value) =>
                    _validateRequiredField(value, 'votre prénom'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[5],
                autocorrect: false,
                decoration:
                    field(
                      'Numéro ou référence de la pièce d’identité',
                      Icons.verified_user_outlined,
                    ).copyWith(
                      helperText: referenceLength < 4
                          ? 'Saisissez le numéro du document ($referenceLength/4 caractères minimum).'
                          : 'Référence renseignée. Elle sera vérifiée par l’administration.',
                    ),
                validator: _validateIdentityReference,
              ),
              sectionTitle(affiliationTitle),
              if (universities.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('registration-university'),
                  isExpanded: true,
                  initialValue: registrationUniversityId,
                  decoration: field('Université', Icons.public),
                  validator: (v) =>
                      v == null ? 'Choisissez votre université.' : null,
                  items: universities
                      .map(
                        (u) => DropdownMenuItem<int>(
                          value: u['id'] as int,
                          child: Text(
                            '${u['nom_univ']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isBusy
                      ? null
                      : (v) => setState(() {
                          registrationUniversityId = v;
                          registrationFacultyId = null;
                          registrationDepartmentId = null;
                          registrationProgramId = null;
                          registrationSpecialtyId = null;
                          registrationLevelId = null;
                          registrationClassId = null;
                        }),
                ),
                const SizedBox(height: 10),
                if (registrationUniversityId != null && faculties.isEmpty)
                  const Text(
                    'La structure académique de cette université doit être configurée par son administration.',
                  ),
              ],
              const Text('Année académique 2026–2027'),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                key: ValueKey(
                  'registration-establishment-$registrationUniversityId',
                ),
                initialValue: registrationFacultyId,
                decoration: field(
                  'Faculté / École / Institut',
                  Icons.school_outlined,
                ),
                validator: (v) =>
                    v == null ? 'Choisissez votre établissement.' : null,
                items: faculties
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'] as int,
                        child: Text(
                          '${f['nom_fac']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isBusy
                    ? null
                    : (v) => setState(() {
                        registrationFacultyId = v;
                        registrationDepartmentId = null;
                        registrationProgramId = null;
                        registrationSpecialtyId = null;
                        registrationLevelId = null;
                        registrationClassId = null;
                      }),
              ),
              const SizedBox(height: 10),
              if (registrationFacultyId != null && visibleDepartments.isEmpty)
                const Text(
                  'Les départements de cet établissement doivent être validés par l’administration.',
                ),
              DropdownButtonFormField<int>(
                isExpanded: true,
                key: ValueKey('department-$registrationFacultyId'),
                initialValue: departmentId,
                decoration: field('Département', Icons.account_tree_outlined),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) =>
                    value == null ? 'Choisissez votre département.' : null,
                items: visibleDepartments
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          '${item['nom_depart']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isBusy
                    ? null
                    : (value) => setState(() {
                        registrationDepartmentId = value;
                        registrationLevelId = null;
                        registrationProgramId = null;
                        registrationSpecialtyId = null;
                        registrationClassId = null;
                      }),
              ),
              if (selectedRole == UserRole.student) ...[
                const SizedBox(height: 10),
                if (years.isEmpty)
                  Text(
                    'Aucune année académique avec classe disponible. Contactez la scolarité.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Inscriptions ouvertes uniquement pour 2026–2027.',
                    ),
                  ),
                if (departmentId != null) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: ValueKey('student-program-$departmentId'),
                    isExpanded: true,
                    initialValue: registrationProgramId,
                    decoration: field('Filière', Icons.menu_book_outlined),
                    validator: (v) =>
                        v == null ? 'Choisissez votre filière.' : null,
                    items: programs
                        .where((f) => f['departement_id'] == departmentId)
                        .map(
                          (f) => DropdownMenuItem<int>(
                            value: f['id'] as int,
                            child: Text(
                              '${f['nom_f']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isBusy
                        ? null
                        : (v) => setState(() {
                            registrationProgramId = v;
                            registrationLevelId = null;
                            registrationClassId = null;
                          }),
                  ),
                ],
                if (registrationProgramId != null) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: ValueKey('student-level-$registrationProgramId'),
                    isExpanded: true,
                    initialValue: registrationLevelId,
                    decoration: field('Niveau', Icons.stairs_outlined),
                    validator: (v) =>
                        v == null ? 'Choisissez votre niveau.' : null,
                    items:
                        {
                              for (final c in classes.where(
                                (c) =>
                                    c['filiere_id'] == registrationProgramId &&
                                    c['annee_id'] == registrationYearId,
                              ))
                                c['niveau_id']: c,
                            }.values
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c['niveau_id'] as int,
                                child: Text(
                                  '${c['libelle_niv'] ?? c['code_niv']}',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: isBusy
                        ? null
                        : (v) => setState(() {
                            registrationLevelId = v;
                            registrationClassId = null;
                          }),
                  ),
                ],
                if (registrationYearId != null && departmentId != null) ...[
                  const SizedBox(height: 10),
                  if (requestedClasses.isEmpty)
                    Text(
                      'Aucune classe n’est disponible dans ce département pour cette année. Contactez la scolarité.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey(
                        'class-$registrationProgramId-$registrationLevelId',
                      ),
                      initialValue: registrationClassId,
                      decoration: field('Classe / salle', Icons.groups_outlined)
                          .copyWith(
                            helperText: 'La classe détermine le niveau, la filière et l’année de votre inscription.',
                          ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) => value == null
                          ? 'Choisissez la classe demandée.'
                          : null,
                      items: requestedClasses.map((item) {
                        final level =
                            item['libelle_niv'] ?? item['code_niv'] ?? 'Niveau';
                        final program = item['nom_f'] ?? item['code_f'] ?? '';
                        final specialty = item['libelle_specialite'];
                        final details =
                            [level, program, if (specialty != null) specialty]
                                .where((value) => '$value'.trim().isNotEmpty)
                                .join(' · ');

                        return DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            '${item['code_classe']} · $details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isBusy
                          ? null
                          : (value) =>
                                setState(() => registrationClassId = value),
                    ),
                ],
              ],
              if (academicPathAvailable) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('teacher-program-$departmentId'),
                  initialValue: programId,
                  decoration: field(programLabel, Icons.school_outlined)
                      .copyWith(
                        helperText: selectedRole == UserRole.teacher
                            ? 'Choisissez votre principal domaine d’enseignement, si vous le connaissez.'
                            : 'Choisissez votre principal domaine d’enseignement, si vous le connaissez.',
                      ),
                  items: programs
                      .where((item) => item['departement_id'] == departmentId)
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            '${item['nom_f']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isBusy
                      ? null
                      : (value) => setState(() {
                          registrationProgramId = value;
                          registrationSpecialtyId = null;
                        }),
                ),
              ],
              if (selectedRole == UserRole.teacher &&
                  programId != null &&
                  specialities.any(
                    (item) => item['filiere_id'] == programId,
                  )) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('teacher-specialty-$programId'),
                  initialValue: registrationSpecialtyId,
                  decoration: field(specialtyLabel, Icons.account_tree_outlined)
                      .copyWith(
                        helperText: selectedRole == UserRole.teacher
                            ? 'Précisez votre domaine de spécialité si nécessaire.'
                            : 'Précisez votre domaine de spécialité si nécessaire.',
                      ),
                  items: specialities
                      .where((item) => item['filiere_id'] == programId)
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            '${item['libelle_specialite']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isBusy
                      ? null
                      : (value) =>
                            setState(() => registrationSpecialtyId = value),
                ),
              ],
              if (departmentId != null &&
                  showsAcademicPath &&
                  !academicPathAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Aucune filière n’est proposée pour ce département. Vérifiez votre choix ou contactez l’administration.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (departmentId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    roleGuidance,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              sectionTitle(accountSectionTitle),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[2],
                autocorrect: false,
                enableSuggestions: false,
                decoration:
                    field(
                      'Identifiant de connexion souhaité',
                      Icons.alternate_email,
                    ).copyWith(
                      helperText:
                          'Lettres, chiffres, point, tiret ou tiret bas.',
                    ),
                validator: _validateLogin,
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[3],
                autocorrect: false,
                decoration: field(
                  profileLabel,
                  Icons.numbers_outlined,
                ).copyWith(helperText: profileHint),
                validator: _validateProfileIdentifier,
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[4],
                keyboardType: TextInputType.emailAddress,
                decoration: field(
                  selectedRole == UserRole.student
                      ? 'Adresse courriel personnelle (facultative)'
                      : 'Adresse courriel professionnelle (facultative)',
                  Icons.email_outlined,
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[6],
                obscureText: true,
                decoration: field('Mot de passe', Icons.lock_outline).copyWith(
                  helperText: '$passwordLength / 12 caractères minimum',
                  suffixIcon: passwordLength >= 12
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                ),
                validator: _validateRegistrationPassword,
              ),
              const SizedBox(height: 10),
              TextFormField(
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: registrationControllers[7],
                obscureText: true,
                decoration:
                    field(
                      'Confirmer le mot de passe',
                      Icons.lock_reset_outlined,
                    ).copyWith(
                      helperText: registrationControllers[7].text.isEmpty
                          ? 'Retapez exactement le même mot de passe.'
                          : registrationControllers[7].text ==
                                registrationControllers[6].text
                          ? 'Les mots de passe correspondent.'
                          : 'La confirmation diffère du mot de passe.',
                      suffixIcon:
                          registrationControllers[7].text.isNotEmpty &&
                              registrationControllers[7].text ==
                                  registrationControllers[6].text
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                    ),
                validator: _validatePasswordConfirmation,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(switch (selectedRole) {
                  UserRole.student => 'Votre demande sera enregistrée dans GNU. Après approbation, votre compte et votre inscription à la classe demandée seront activés.',
                  UserRole.teacher => 'Votre demande sera enregistrée dans GNU. L’administration vérifiera votre identité et votre rattachement avant activation.',
                  UserRole.agent => 'Votre demande sera enregistrée dans GNU. Un administrateur vérifiera votre identité et votre service avant activation.',
                }, style: TextStyle(height: 1.45, fontSize: 12)),
              ),
              if (registrationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    registrationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isBusy ? null : _submitAccountRegistration,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(isBusy ? 'Enregistrement…' : submitLabel),
              ),
              TextButton(
                onPressed: isBusy
                    ? null
                    : () => setState(() => registrationStructure = null),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 800;
        final stacked = box.maxWidth < 900;
        final intro = Container(
          padding: EdgeInsets.all(compact ? 28 : 56),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF102B36), Color(0xFF124E4B)],
            ),
            borderRadius: compact
                ? BorderRadius.zero
                : const BorderRadius.only(
                    topRight: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Brand(dark: true),
              SizedBox(height: compact ? 38 : 68),
              const Text(
                'LE SAVOIR AVANCE.\nVOTRE CAMPUS AUSSI.',
                style: TextStyle(
                  color: Color(0xFF81D3BD),
                  letterSpacing: 2.2,
                  fontSize: 11,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Un campus connecté.\nDes parcours simplifiés.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 32 : 40,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Notes, enseignements et suivi académique :\nun espace clair pour chaque membre de l’université.',
                style: TextStyle(
                  color: Color(0xFFBAD0D0),
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
              SizedBox(height: compact ? 28 : 48),
              ...[
                (Icons.school_outlined, 'Votre parcours, au même endroit'),
                (
                  Icons.fact_check_outlined,
                  'Des étapes de validation lisibles',
                ),
                (Icons.devices_outlined, 'Sur ordinateur, tablette et mobile'),
              ].map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    children: [
                      Icon(item.$1, color: const Color(0xFF81D3BD), size: 21),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 42),
              const Text(
                'GNU  /  GESTION DES NOTES UNIVERSITAIRES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        );
        final chooser = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 490),
            child: Padding(
              padding: EdgeInsets.all(compact ? 24 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [const Brand(), StatusBadge('ACCÈS SÉCURISÉ')],
                  ),
                  const SizedBox(height: 38),
                  StatusBadge('PORTAIL ${selectedRole.label.toUpperCase()}'),
                  const SizedBox(height: 18),
                  Text(
                    'Bienvenue sur GNU',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Gestion des notes universitaires · 2026–2027'),
                  if (widget.onBrowseDirectory != null)
                    TextButton.icon(
                      onPressed: widget.onBrowseDirectory,
                      icon: const Icon(Icons.public),
                      label: const Text('Consulter l’annuaire public'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Choisissez votre espace, puis connectez-vous avec les identifiants fournis pour votre compte ${selectedRole.label.toLowerCase()}.',
                    style: TextStyle(color: muted, height: 1.7),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<UserRole>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: UserRole.student,
                          label: Text('Étudiant'),
                          icon: Icon(Icons.school_outlined),
                        ),
                        ButtonSegment(
                          value: UserRole.teacher,
                          label: Text('Enseignant'),
                          icon: Icon(Icons.cast_for_education_outlined),
                        ),
                        ButtonSegment(
                          value: UserRole.agent,
                          label: Text('Agent'),
                          icon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                      ],
                      selected: {selectedRole},
                      onSelectionChanged:
                          loggingIn ||
                              registrationLoading ||
                              registrationSending
                          ? null
                          : (selection) =>
                                _selectRegistrationRole(selection.first),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_needsNativeApiAddress) ...[
                    TextField(
                      controller: apiBaseUrlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Adresse du serveur GNU',
                        hintText: 'http://192.168.1.10:8000/api/v1',
                        helperText: 'Sur téléphone, remplacez 10.0.2.2 par l’adresse IP du PC.',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: loginController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant de connexion',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: showPassword
                            ? 'Masquer le mot de passe'
                            : 'Afficher le mot de passe',
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (loginError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        loginError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (registrationNotice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        registrationNotice!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loggingIn ? null : _submitLogin,
                      icon: const Icon(Icons.login),
                      label: Text(loggingIn ? 'Connexion…' : 'Se connecter'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Vous découvrez GNU ?',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                  TextButton.icon(
                    onPressed: registrationLoading ? null : _requestAccount,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(
                      registrationLoading ? 'Chargement…' : 'S’inscrire',
                    ),
                  ),
                  const Text(
                    'Inscrivez-vous en quelques étapes. Votre accès sera activé après vérification par l’administration.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  _registrationForm(),
                ],
              ),
            ),
          ),
        );
        return stacked
            ? SingleChildScrollView(child: Column(children: [intro, chooser]))
            : Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: intro,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: chooser,
                      ),
                    ),
                  ),
                ],
              );
      },
    ),
  );
}

typedef Destination = ({String id, String label, IconData icon});
List<Destination> destinations(UserRole role) => [
  if (role != UserRole.teacher)
    (id: 'home', label: 'Vue d’ensemble', icon: Icons.grid_view_rounded),
  ...switch (role) {
    UserRole.student => [
      (
        id: 'results',
        label: 'Notes & bulletins',
        icon: Icons.insert_chart_outlined,
      ),
      (id: 'guide', label: 'Guide & normes', icon: Icons.menu_book_outlined),
      (
        id: 'enrollment',
        label: 'Inscription pédagogique',
        icon: Icons.playlist_add_check_outlined,
      ),
      (id: 'requests', label: 'Mes requêtes', icon: Icons.chat_bubble_outline),
      (id: 'retakes', label: 'Mes rattrapages', icon: Icons.event_repeat),
      (
        id: 'profile',
        label: 'Profil & notifications',
        icon: Icons.account_circle_outlined,
      ),
    ],
    UserRole.teacher => [
      (id: 'classes', label: 'Mes niveaux', icon: Icons.class_outlined),
      (
        id: 'gradebook',
        label: 'Notes & validations',
        icon: Icons.fact_check_outlined,
      ),
      (id: 'requests', label: 'Requêtes & UE', icon: Icons.forum_outlined),
      (
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
      ),
      (id: 'profile', label: 'Mon compte', icon: Icons.account_circle_outlined),
    ],
    UserRole.agent => [
      (
        id: 'academic',
        label: 'Structure & catalogue',
        icon: Icons.account_tree_outlined,
      ),
      (
        id: 'accounts',
        label: 'Comptes & affectations',
        icon: Icons.people_outline,
      ),
      (
        id: 'enrollment',
        label: 'Inscriptions',
        icon: Icons.playlist_add_check_outlined,
      ),
      (
        id: 'requests',
        label: 'Requêtes étudiantes',
        icon: Icons.forum_outlined,
      ),
      (
        id: 'grade-transmissions',
        label: 'Traitement des PV',
        icon: Icons.fact_check_outlined,
      ),
      (
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
      ),
      (
        id: 'normal-sessions',
        label: 'Sessions normales',
        icon: Icons.event_available_outlined,
      ),
      (
        id: 'retakes',
        label: 'Sessions de rattrapage',
        icon: Icons.event_repeat,
      ),
      (
        id: 'bulletins',
        label: 'Bulletins & publications',
        icon: Icons.publish_outlined,
      ),
      (id: 'audit', label: 'Journal d’audit', icon: Icons.history_outlined),
      (id: 'profile', label: 'Mon profil', icon: Icons.account_circle_outlined),
    ],
  },
];

class Portal extends StatefulWidget {
  const Portal({
    super.key,
    required this.role,
    required this.store,
    required this.onExit,
    this.apiClient,
    this.darkMode = false,
    this.onToggleTheme = _noop,
  });
  final UserRole role;
  final DemoStore store;
  final VoidCallback onExit;
  final StudentApiClient? apiClient;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  static void _noop() {}
  @override
  State<Portal> createState() => _PortalState();
}

class _PortalState extends State<Portal> {
  String page = 'home';
  final scroll = ScrollController();
  final liveStudentPageKey = GlobalKey<LiveStudentPageState>();
  List<Map<String, dynamic>> academicYears = [];
  String? selectedAcademicYearId;

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.teacher) page = 'classes';
    unawaited(_loadAcademicYears());
  }

  Future<void> _loadAcademicYears() async {
    final api = widget.apiClient;
    if (api == null) return;
    try {
      final years = await api.academicYears();
      final saved = await api.readAcademicYearPreference();
      final today = DateTime.now();
      final current = years.where((year) {
        final start = DateTime.tryParse('${year['date_debut'] ?? ''}');
        final end = DateTime.tryParse('${year['date_fin'] ?? ''}');
        return start != null &&
            end != null &&
            !today.isBefore(start) &&
            !today.isAfter(end);
      }).toList();
      final selected = years.any((year) => '${year['id']}' == saved)
          ? saved
          : current.isEmpty
          ? (years.isEmpty ? null : '${years.first['id']}')
          : '${current.first['id']}';
      if (selected != null) await api.selectAcademicYear(selected);
      if (mounted) {
        setState(() {
          academicYears = years;
          selectedAcademicYearId = selected;
        });
      }
    } catch (_) {
      // Keep the portal usable if the academic reference endpoint is unavailable.
    }
  }

  Future<void> _selectAcademicYear(String? id) async {
    if (id == null || id == selectedAcademicYearId) return;
    await widget.apiClient?.selectAcademicYear(id);
    if (!mounted) return;
    setState(() => selectedAcademicYearId = id);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => liveStudentPageKey.currentState?.refresh(),
    );
  }

  String get _displayName {
    final user = widget.apiClient?.user;
    if (user == null) return widget.role.displayName;
    return '${user['prenom'] ?? ''} ${user['nom'] ?? ''}'.trim();
  }

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void navigate(String value) {
    setState(() => page = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Widget sidebar(bool drawer) => Container(
    color: const Color(0xFF12343A),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 20, 22),
            child: Brand(dark: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4548),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF315B5D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESPACE PERSONNEL',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      color: const Color(0xFF9BBAB5),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.role.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'MON CAMPUS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: const Color(0xFF9BBAB5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: destinations(widget.role)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          minVerticalPadding: 14,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          selected: page == item.id,
                          selectedTileColor: const Color(0xFF24574F),
                          selectedColor: const Color(0xFF8BE0C8),
                          iconColor: const Color(0xFFB1C8C5),
                          leading: Icon(item.icon, size: 20),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: page == item.id
                                  ? const Color(0xFF9AE5CF)
                                  : const Color(0xFFD4E2DF),
                              fontSize: 13,
                              fontWeight: page == item.id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            if (drawer) Navigator.pop(context);
                            navigate(item.id);
                          },
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF315257)),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF24574F),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Color(0xFF9AE5CF),
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                _displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Compte connecté · ${widget.apiClient!.user?['profil']?['matricule'] ?? widget.apiClient!.user?['profil']?['eid'] ?? widget.role.label}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF9BBAB5)),
              ),
              trailing: IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(
                  Icons.logout,
                  size: 18,
                  color: Color(0xFFB1C8C5),
                ),
                onPressed: widget.onExit,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1100;
        return Scaffold(
          drawer: wide ? null : Drawer(width: 280, child: sidebar(true)),
          body: Row(
            children: [
              if (wide) ...[
                SizedBox(width: 264, child: sidebar(false)),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(color: palette(context, stroke)),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 36 : 16,
                        vertical: 13,
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            if (!wide)
                              Builder(
                                builder: (context) => IconButton(
                                  tooltip: 'Ouvrir le menu',
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const Icon(Icons.menu),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                'Espace ${widget.role.label.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette(context, muted),
                                ),
                              ),
                            ),
                            if (box.maxWidth > 600) ...[
                              Icon(
                                Icons.calendar_today_outlined,
                                color: palette(context, muted),
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      academicYears.any(
                                        (year) =>
                                            '${year['id']}' ==
                                            selectedAcademicYearId,
                                      )
                                      ? selectedAcademicYearId
                                      : null,
                                  hint: const Text(
                                    'Année académique',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  items: academicYears
                                      .map(
                                        (year) => DropdownMenuItem(
                                          value: '${year['id']}',
                                          child: Text(
                                            '${year['libelle']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _selectAcademicYear,
                                ),
                              ),
                              const SizedBox(width: 24),
                            ],
                            const StatusBadge('CONNECTÉ', color: emerald),
                            const SizedBox(width: 8),
                            if (widget.apiClient != null &&
                                widget.role == UserRole.student)
                              IconButton(
                                tooltip: 'Actualiser les données du serveur',
                                onPressed: () =>
                                    liveStudentPageKey.currentState?.refresh(),
                                icon: const Icon(Icons.refresh),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: widget.darkMode
                                  ? 'Passer au thème clair'
                                  : 'Passer au thème sombre',
                              onPressed: widget.onToggleTheme,
                              icon: Icon(
                                widget.darkMode
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Aide et fonctionnement',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Votre espace GNU'),
                                  content: Text(
                                    'Vous êtes connecté au backend GNU. Les inscriptions, résultats, requêtes et notifications sont chargés depuis le serveur.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Compris'),
                                    ),
                                  ],
                                ),
                              ),
                              icon: Icon(
                                Icons.help_outline,
                                size: 21,
                                color: palette(context, muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scroll,
                        padding: EdgeInsets.fromLTRB(
                          box.maxWidth < 650 ? 18 : 36,
                          box.maxWidth < 650 ? 24 : 32,
                          box.maxWidth < 650 ? 18 : 36,
                          36,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.apiClient != null &&
                                    widget.role == UserRole.student &&
                                    page != 'guide')
                                  LiveStudentPage(
                                    key: liveStudentPageKey,
                                    page: page,
                                    api: widget.apiClient!,
                                    onNavigate: navigate,
                                  )
                                else if (widget.apiClient != null &&
                                    widget.role == UserRole.student)
                                  FeaturePage(
                                    key: ValueKey('${widget.role}-$page'),
                                    page: page,
                                    role: widget.role,
                                    store: widget.store,
                                  )
                                else if (widget.apiClient != null &&
                                    widget.role == UserRole.teacher &&
                                    (page == 'profile' ||
                                        page == 'notifications'))
                                  TeacherAccountPage(
                                    key: ValueKey('teacher-account-$page'),
                                    api: widget.apiClient!,
                                    page: page,
                                  )
                                else if (widget.apiClient != null &&
                                    widget.role == UserRole.teacher)
                                  TeacherAssignmentsPage(
                                    key: ValueKey(
                                      'teacher-$page-$selectedAcademicYearId',
                                    ),
                                    api: widget.apiClient!,
                                    page: page,
                                  )
                                else if (widget.apiClient != null &&
                                    widget.role == UserRole.agent)
                                  AgentPortalPage(
                                    key: ValueKey(
                                      'agent-$page-$selectedAcademicYearId',
                                    ),
                                    page: page,
                                    api: widget.apiClient!,
                                    onNavigate: navigate,
                                    onExit: widget.onExit,
                                    onAcademicYearSelected: _selectAcademicYear,
                                  )
                                else if (widget.apiClient == null)
                                  const Notice(
                                    'Une session valide est nécessaire pour consulter cet espace.',
                                    warning: true,
                                  )
                                else
                                  LiveStudentPage(
                                    key: liveStudentPageKey,
                                    page: page,
                                    api: widget.apiClient!,
                                    onNavigate: navigate,
                                  ),
                                const SizedBox(height: 36),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  'GNU · Campus numérique     /     Session ${widget.role.label.toLowerCase()} connectée',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette(context, muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
