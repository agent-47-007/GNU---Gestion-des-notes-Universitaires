import 'package:flutter/material.dart';

import 'domain.dart';
import 'ui.dart';
import 'pages.dart';

void main() => runApp(const GnuApp());

class GnuApp extends StatefulWidget {
  const GnuApp({super.key});
  @override
  State<GnuApp> createState() => _GnuAppState();
}

class _GnuAppState extends State<GnuApp> {
  final store = DemoStore();
  UserRole? role;
  bool darkMode = false;
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GNU · Campus numérique',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(dark: darkMode),
    home: role == null
        ? WelcomePage(onEnter: (value) => setState(() => role = value))
        : Portal(
            key: ValueKey(role),
            role: role!,
            store: store,
            onExit: () => setState(() => role = null),
            darkMode: darkMode,
            onToggleTheme: () => setState(() => darkMode = !darkMode),
          ),
  );
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onEnter});
  final ValueChanged<UserRole> onEnter;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  UserRole selected = UserRole.student;
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
                  const StatusBadge('APERÇU INTERACTIF · VERSION 2'),
                  const SizedBox(height: 25),
                  Text(
                    'Bienvenue sur GNU',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choisissez un espace pour découvrir votre nouveau portail académique.',
                    style: TextStyle(color: muted, height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  ...UserRole.values.map(
                    (role) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        selected: selected == role,
                        child: Material(
                          color: selected == role
                              ? const Color(0xFFEBF6F2)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected == role ? emerald : stroke,
                              width: selected == role ? 1.5 : 1,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => selected = role),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Icon(switch (role) {
                                    UserRole.student => Icons.school_outlined,
                                    UserRole.teacher =>
                                      Icons.menu_book_outlined,
                                    UserRole.agent =>
                                      Icons.admin_panel_settings_outlined,
                                  }, color: selected == role ? emerald : muted),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          role.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          switch (role) {
                                            UserRole.student =>
                                              'Mon parcours et mes résultats',
                                            UserRole.teacher =>
                                              'Mes cours et mes évaluations',
                                            UserRole.agent =>
                                              'Administration et publications',
                                          },
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    selected == role
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 20,
                                    color: selected == role ? emerald : muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => widget.onEnter(selected),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Explorer cet espace'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Données fictives · Aucun compte requis\nLes modifications restent dans cette session et sont effacées au rechargement.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.7),
                  ),
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
      (
        id: 'profile',
        label: 'Profil & notifications',
        icon: Icons.account_circle_outlined,
      ),
    ],
    UserRole.teacher => [
      (id: 'classes', label: 'Classes & matières', icon: Icons.class_outlined),
      (id: 'grades', label: 'Saisie des notes', icon: Icons.edit_note),
      (id: 'evaluations', label: 'Plans d’évaluation', icon: Icons.tune),
      (
        id: 'requests',
        label: 'Requêtes étudiantes',
        icon: Icons.chat_bubble_outline,
      ),
      (id: 'retakes', label: 'Rattrapages', icon: Icons.event_repeat),
    ],
    UserRole.agent => [
      (
        id: 'academic',
        label: 'Structure & programmes',
        icon: Icons.account_tree_outlined,
      ),
      (
        id: 'accounts',
        label: 'Comptes & affectations',
        icon: Icons.people_outline,
      ),
      (
        id: 'bulletins',
        label: 'Gestion des bulletins',
        icon: Icons.description_outlined,
      ),
      (id: 'audit', label: 'Journal d’audit', icon: Icons.history_outlined),
      (
        id: 'enrollment',
        label: 'Inscriptions',
        icon: Icons.playlist_add_check_outlined,
      ),
      (
        id: 'publications',
        label: 'Validation & publication',
        icon: Icons.publish_outlined,
      ),
    ],
  },
];

class Portal extends StatefulWidget {
  const Portal({
    super.key,
    required this.role,
    required this.store,
    required this.onExit,
    this.darkMode = false,
    this.onToggleTheme = _noop,
  });
  final UserRole role;
  final DemoStore store;
  final VoidCallback onExit;
  final bool darkMode;
  final VoidCallback onToggleTheme;

  static void _noop() {}
  @override
  State<Portal> createState() => _PortalState();
}

class _PortalState extends State<Portal> {
  String page = 'home';
  final scroll = ScrollController();
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
    color: Colors.white,
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
                color: canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ESPACE PERSONNEL',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      color: muted,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'MON CAMPUS',
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: muted),
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
                    style: TextStyle(
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
                  widget.role.initials,
                  style: const TextStyle(color: emerald, fontSize: 12),
                ),
              ),
              title: Text(
                widget.role.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Profil de démonstration',
                style: TextStyle(fontSize: 10),
              ),
              trailing: IconButton(
                tooltip: 'Changer d’espace',
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
                      color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: muted,
                                ),
                              ),
                            ),
                            if (box.maxWidth > 600) ...[
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: muted,
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Année 2026 – 2027',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 24),
                            ],
                            const StatusBadge('DÉMO', color: Color(0xFFA26917)),
                            const SizedBox(width: 8),
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
                                  content: const Text(
                                    'Cet aperçu utilise uniquement des données fictives. Vous pouvez changer d’espace pour tester un parcours complet : saisie enseignant, transmission, puis publication agent.\n\nLes modifications et les pièces jointes restent en mémoire jusqu’au rechargement. L’authentification et les autorisations réelles seront assurées par le serveur.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Compris'),
                                    ),
                                  ],
                                ),
                              ),
                              icon: const Icon(
                                Icons.help_outline,
                                size: 21,
                                color: muted,
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
                                if (page == 'home')
                                  Dashboard(
                                    role: widget.role,
                                    store: widget.store,
                                    navigate: navigate,
                                  )
                                else
                                  FeaturePage(
                                    key: ValueKey('${widget.role}-$page'),
                                    page: page,
                                    role: widget.role,
                                    store: widget.store,
                                  ),
                                const SizedBox(height: 36),
                                const Divider(),
                                const SizedBox(height: 12),
                                const Text(
                                  'GNU · Campus numérique     /     Données de démonstration — session temporaire',
                                  style: TextStyle(fontSize: 11, color: muted),
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
