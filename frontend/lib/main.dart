import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'agent_portal.dart';
import 'api_client.dart';
import 'domain.dart';
import 'ui.dart';
import 'pages.dart';
import 'student_portal.dart';
import 'teacher_portal.dart';
import 'local_portal_navigation.dart';

const _compiledApiBaseUrl = String.fromEnvironment('GNU_API_BASE_URL');

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
  bool darkMode = false;
  StudentApiClient? liveStudentApi;

  StudentApiClient _roleClient(UserRole role) {
    final client = StudentApiClient(
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
        ? WelcomePage(onRoleLogin: _loginRole)
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
  ) async {
    final client = _roleClient(selectedRole);
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
  const WelcomePage({super.key, required this.onRoleLogin});
  final Future<void> Function(UserRole role, String login, String password)
  onRoleLogin;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  UserRole selectedRole = UserRole.student;
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  bool loggingIn = false;
  String? loginError;

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() {
      loggingIn = true;
      loginError = null;
    });
    try {
      await widget.onRoleLogin(
        selectedRole,
        loginController.text,
        passwordController.text,
      );
    } catch (error) {
      if (mounted) setState(() => loginError = error.toString());
    } finally {
      if (mounted) setState(() => loggingIn = false);
    }
  }

  void _openLocalTestAccountPortal() {
    final uri = Uri.tryParse(_compiledApiBaseUrl.trim());
    if (uri == null ||
        !const ['localhost', '127.0.0.1', '::1'].contains(uri.host)) {
      setState(() {
        loginError = 'Le portail de création est réservé à votre installation locale : http://127.0.0.1:8000/local-test-accounts';
      });
      return;
    }

    final portal = uri.replace(
      path: '/local-test-accounts',
      query: null,
      fragment: null,
    );
    if (kIsWeb) {
      navigateToLocalPortal(portal.toString());
    } else {
      setState(() => loginError = 'Ouvrez le portail local : $portal');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, box) {
        final intro = Container(
          padding: EdgeInsets.all(box.maxWidth < 800 ? 28 : 56),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navy, Color(0xFF124E4B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Brand(dark: true),
              const SizedBox(height: 68),
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
              const Text(
                'Un campus connecté.\nDes parcours simplifiés.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
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
              const SizedBox(height: 48),
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
              padding: EdgeInsets.all(box.maxWidth < 800 ? 24 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge('PORTAIL ${selectedRole.label.toUpperCase()}'),
                  const SizedBox(height: 25),
                  Text(
                    'Bienvenue sur GNU',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choisissez votre espace, puis connectez-vous avec les identifiants fournis pour votre compte ${selectedRole.label.toLowerCase()}.',
                    style: TextStyle(color: muted, height: 1.7),
                  ),
                  const SizedBox(height: 22),
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
                      onSelectionChanged: loggingIn
                          ? null
                          : (selection) =>
                                setState(() => selectedRole = selection.first),
                    ),
                  ),
                  const SizedBox(height: 22),
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
                    obscureText: true,
                    onSubmitted: (_) => _submitLogin(),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: Icon(Icons.lock_outline),
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
                    'Vous n’avez pas encore de compte ?',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                  TextButton.icon(
                    onPressed: _openLocalTestAccountPortal,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Créer un compte de test'),
                  ),
                  const Text(
                    'Ce portail est réservé aux essais sur votre ordinateur. En production, les comptes sont créés par le service compétent.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
        return box.maxWidth < 900
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
      (id: 'classes', label: 'Mes affectations', icon: Icons.class_outlined),
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
        label: 'Numérisation des notes',
        icon: Icons.fact_check_outlined,
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
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(26, 30, 24, 26),
            child: Brand(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette(context, canvas),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESPACE PERSONNEL',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      color: palette(context, muted),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.role.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 27),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'MON CAMPUS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: palette(context, muted),
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
                          selectedTileColor: const Color(0xFFE9F4F0),
                          selectedColor: emerald,
                          iconColor: muted,
                          leading: Icon(item.icon, size: 20),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFF87D8C0),
                    size: 21,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Un nouvel espace pour vous',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Des démarches simples, un suivi plus clair.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE9F4F0),
                child: Text(
                  _initials,
                  style: const TextStyle(color: emerald, fontSize: 12),
                ),
              ),
              title: Text(
                _displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Compte connecté · ${widget.apiClient!.user?['profil']?['matricule'] ?? widget.apiClient!.user?['profil']?['eid'] ?? widget.role.label}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout, size: 18),
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
                      color: Theme.of(context).colorScheme.surface,
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 36 : 16,
                        vertical: 16,
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
                        padding: EdgeInsets.all(box.maxWidth < 650 ? 20 : 36),
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
                                    widget.role == UserRole.teacher)
                                  TeacherAssignmentsPage(
                                    key: ValueKey(
                                      'teacher-$page-$selectedAcademicYearId',
                                    ),
                                    api: widget.apiClient!,
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
