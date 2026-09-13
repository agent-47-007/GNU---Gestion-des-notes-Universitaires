import 'package:flutter/material.dart';

const ink = Color(0xFF1B2942);
const paper = Color(0xFFDEDACB);
const paperLight = Color(0xFFF1EEE2);
const red = Color(0xFF8C2F2F);
const gold = Color(0xFFA9762C);
const slate = Color(0xFF5B5F66);
const valid = Color(0xFF3C6E52);
const pending = Color(0xFFC4841F);

void main() => runApp(const GnuApp());

class GnuApp extends StatelessWidget {
  const GnuApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GNU — Gestion des notes',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: red, primary: red, surface: paperLight),
          fontFamily: 'IBM Plex Sans',
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 32),
            headlineMedium: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 25),
            titleLarge: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 20),
            bodyMedium: TextStyle(color: ink, height: 1.35),
            labelSmall: TextStyle(fontFamily: 'monospace', letterSpacing: 1.1, color: slate),
          ),
        ),
        home: const LoginPage(),
      );
}

enum Role { enseignant, cellule, etudiant }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Role role = Role.enseignant;
  final login = TextEditingController(text: 'ENS-4182-INFO');
  bool obscurePassword = true;
  bool stayConnected = true;

  String get roleHint => switch (role) {
        Role.enseignant => 'ENS-4182-INFO',
        Role.cellule => 'ADM-8842-CELLULE',
        Role.etudiant => '21T2355',
      };

  String get roleLabel => switch (role) {
        Role.enseignant => 'Identifiant enseignant',
        Role.cellule => 'Identifiant agent / jury',
        Role.etudiant => 'Matricule étudiant',
      };

  void selectRole(Role value) {
    setState(() {
      role = value;
      login.text = roleHint;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: paper,
          title: GnuBrand(),
          actions: [
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidePage())), child: const Text('Guide & Normes LMD')),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())), child: const Text('Support & Registres')),
            const SizedBox(width: 18),
          ],
        ),
        body: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = Padding(
            padding: const EdgeInsets.fromLTRB(48, 42, 48, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Image.asset('assets/logo_gnu.png', width: 64, height: 64), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('PORTAIL UNIVERSITAIRE', style: TextStyle(fontFamily: 'monospace', color: red, letterSpacing: 1.5)), const SizedBox(height: 6), Text('Connexion au Système GNU', style: Theme.of(context).textTheme.headlineLarge)] )]),
                const SizedBox(height: 6),
                const Padding(padding: EdgeInsets.only(left: 80), child: Text('Gestion des Notes & Délibérations · Licence, Master, Doctorat')),
                const SizedBox(height: 26),
                const Text('Vous vous connectez en tant que :'),
                const SizedBox(height: 8),
                SegmentedButton<Role>(segments: const [
                  ButtonSegment(value: Role.enseignant, label: Text('Enseignant'), icon: Icon(Icons.school_outlined)),
                  ButtonSegment(value: Role.cellule, label: Text('Scolarité / Jury'), icon: Icon(Icons.account_balance_outlined)),
                  ButtonSegment(value: Role.etudiant, label: Text('Étudiant'), icon: Icon(Icons.person_outline)),
                ], selected: {role}, onSelectionChanged: (v) => selectRole(v.first)),
                const SizedBox(height: 20),
                TextField(controller: login, decoration: InputDecoration(labelText: roleLabel, hintText: roleHint, filled: true, fillColor: const Color(0xFFE7E3D5), border: InputBorder.none)),
                const SizedBox(height: 14),
                TextField(obscureText: obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', hintText: 'Votre mot de passe institutionnel', filled: true, fillColor: const Color(0xFFE7E3D5), border: InputBorder.none, suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscurePassword = !obscurePassword)))),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Mot de passe oublié ?'))),
                CheckboxListTile(value: stayConnected, onChanged: (value) => setState(() => stayConnected = value ?? false), contentPadding: EdgeInsets.zero, title: const Text('Rester connecté sur cet appareil')),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleHome(role: role))), icon: const Icon(Icons.login), label: const Padding(padding: EdgeInsets.all(14), child: Text('SE CONNECTER')))),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Besoin d’assistance avec votre compte ?', style: TextStyle(color: slate)), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())), child: const Text('Contacter le support universitaire'))]),
              ]),
            ),
          );
          final panel = Container(color: ink, padding: const EdgeInsets.fromLTRB(40, 42, 40, 30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SYSTÈME LMD UNIVERSITAIRE', style: TextStyle(color: paperLight, fontFamily: 'monospace', letterSpacing: 1.5)), const SizedBox(height: 18), Text('GNU — Gestion des Notes & Évaluations', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: paperLight)), const SizedBox(height: 14), const Text('Plateforme académique unifiée pour la gestion complète du cycle universitaire.', style: TextStyle(color: paper, fontSize: 16)), const SizedBox(height: 30), const _Feature(icon: Icons.edit_note, title: '1. Saisie des Notes', text: 'Contrôle continu, travaux pratiques et sessions d’examen.'), const _Feature(icon: Icons.calculate_outlined, title: '2. Calculs & Crédits ECTS', text: 'Calcul automatique des moyennes et règles de compensation.'), const _Feature(icon: Icons.description_outlined, title: '3. Délibérations & Relevés', text: 'Génération des procès-verbaux et relevés officiels.'), const SizedBox(height: 20), const Divider(color: Colors.white24), const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Année Académique 2024–2025', style: TextStyle(color: paper)), const Text('Licence · Master · Doctorat', style: TextStyle(color: paper))])]));
          final pageWidth = wide ? 1200.0 : constraints.maxWidth;
          final content = Center(child: SizedBox(width: pageWidth, child: Card(clipBehavior: Clip.antiAlias, child: wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: form), Expanded(child: panel)]) : Column(children: [form, panel]))));
          return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(40, 32, 40, 28), child: Column(children: [content, const SizedBox(height: 32), SizedBox(width: pageWidth, child: const _LoginFeatureRow()), const SizedBox(height: 28), SizedBox(width: pageWidth, child: const _LoginFooter())]));
        }),
      );
}

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});
  @override
  Widget build(BuildContext context) => _SimplePage(
        title: 'Guide & Barème des Notes LMD',
        eyebrow: 'BARÈME · MODALITÉS · FORMULES DE CALCUL',
        action: 'Déposer une requête',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())),
        children: [
          _GuideIntro(),
          const SizedBox(height: 18),
          _GuideSection(number: '§ 01', title: 'Grille Officielle de Notation & Échelle des Mentions', kicker: 'SYSTÈME DE POINTS SUR 4.00', child: const _GradeTable()),
          const SizedBox(height: 18),
          _GuideSection(number: '§ 02', title: 'Modalités d’Évaluation & Formules de Calcul', kicker: 'PONDÉRATIONS OFFICIELLES', child: const _EvaluationRules()),
          const SizedBox(height: 18),
          _GuideSection(number: '§ 03', title: 'Formule de la Moyenne Générale Pondérée (MGP)', kicker: 'BARÈME GPA INTERNATIONAL', child: const _MgpRules()),
          const SizedBox(height: 18),
          _GuideSection(number: '§ 04', title: 'Règles de Progression & Validation des Cycles', kicker: 'CONDITIONS DE PASSAGE', child: const _CycleRules()),
          const SizedBox(height: 18),
          _GuideSection(number: '§ 05', title: 'Lexique Essentiel des Notes & Notions LMD', kicker: 'FICHES REPÈRES', child: const _Glossary()),
        ],
      );
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context) => _SimplePage(
        title: 'Registres Académiques & Cellule de Support',
        eyebrow: 'DÉLIBÉRATIONS · RECOURS · REGISTRES MATRICULAIRES',
        action: 'Déposer une requête',
        onAction: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le formulaire officiel de requête se trouve dans la section § 02.'))),
        children: const [_SupportContent()],
      );
}

class _GuideIntro extends StatelessWidget {
  const _GuideIntro();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Système d’Évaluation & Gestion des Notes (LMD)', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: ink)), SizedBox(height: 8), Text('Modalités de calcul des moyennes, barème de notation sur 100 points, calcul de la Moyenne Générale Pondérée (MGP) et règles de progression académique en Licence, Master et Doctorat.')])),
            const SizedBox(width: 20),
            OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le barème est prêt pour impression depuis le navigateur.'))), icon: const Icon(Icons.print_outlined), label: const Text('Imprimer le Barème')),
          ]),
        ),
      );
}

class _GuideSection extends StatelessWidget {
  final String number, title, kicker; final Widget child;
  const _GuideSection({required this.number, required this.title, required this.kicker, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('$number  $title', style: Theme.of(context).textTheme.titleLarge), Text(kicker, style: Theme.of(context).textTheme.labelSmall)]),
            const Divider(),
            child,
          ]),
        ),
      );
}

class _GradeTable extends StatelessWidget {
  const _GradeTable();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Le grade et les points de MGP sont déterminés à partir de la note entière de l’UE sur 100, après arrondi à l’entier supérieur. La conservation ou la reprise s’apprécie lors de la réinscription ; l’admission dépend du bilan annuel.'),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('NOTE / 100')), DataColumn(label: Text('GRADE')), DataColumn(label: Text('POINTS')), DataColumn(label: Text('MENTION / DÉCISION')), DataColumn(label: Text('STATUT'))], rows: const [
          DataRow(cells: [DataCell(Text('80 – 100')), DataCell(Text('A+')), DataCell(Text('4.00')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('75 – 79')), DataCell(Text('A−')), DataCell(Text('3.70')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('70 – 74')), DataCell(Text('B+')), DataCell(Text('3.30')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('65 – 69')), DataCell(Text('B')), DataCell(Text('3.00')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('60 – 64')), DataCell(Text('B−')), DataCell(Text('2.70')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('55 – 59')), DataCell(Text('C+')), DataCell(Text('2.30')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('50 – 54')), DataCell(Text('C')), DataCell(Text('2.00')), DataCell(Text('UE ≥ 50/100')), DataCell(Text('À conserver'))]),
          DataRow(cells: [DataCell(Text('45 – 49')), DataCell(Text('C−')), DataCell(Text('1.70')), DataCell(Text('UE < 50/100')), DataCell(Text('À reprendre'))]),
          DataRow(cells: [DataCell(Text('40 – 44')), DataCell(Text('D+')), DataCell(Text('1.30')), DataCell(Text('UE < 50/100')), DataCell(Text('À reprendre'))]),
          DataRow(cells: [DataCell(Text('35 – 39')), DataCell(Text('D−')), DataCell(Text('1.00')), DataCell(Text('UE < 50/100')), DataCell(Text('À reprendre'))]),
          DataRow(cells: [DataCell(Text('30 – 34')), DataCell(Text('E')), DataCell(Text('0.00')), DataCell(Text('Sous le minimum annuel de 35/100')), DataCell(Text('À reprendre'))]),
          DataRow(cells: [DataCell(Text('0 – 29')), DataCell(Text('F')), DataCell(Text('0.00')), DataCell(Text('Sous le minimum annuel de 35/100')), DataCell(Text('À reprendre'))]),
          DataRow(cells: [DataCell(Text('Sans note numérique')), DataCell(Text('EL')), DataCell(Text('0.00')), DataCell(Text('Absence au rattrapage')), DataCell(Text('À reprendre'))]),
        ])),
        const SizedBox(height: 14),
        const Wrap(spacing: 8, runSpacing: 8, children: [_StatusChip(label: 'UE à reprendre : tous les EC sont réévalués'), _StatusChip(label: 'EL : absence au rattrapage uniquement')]),
      ]);
}

class _EvaluationRules extends StatelessWidget {
  const _EvaluationRules();
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('Les notes sont calculées sur 100. Une note saisie sur 20 est convertie en la multipliant par 5. Chaque EC possède un plan d’évaluation actif dont les poids retenus totalisent 100 %. Les répartitions ci-dessous sont des exemples de plans.'),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: _RuleCard(title: 'Exemple : EC avec Travaux Pratiques (TP)', values: ['Contrôle continu 20 %', 'Travaux pratiques 30 %', 'Session normale 50 %'], formula: 'EC brut /100 = (CC × 0.20) + (TP × 0.30) + (SN × 0.50)')),
          const SizedBox(width: 14),
          const Expanded(child: _RuleCard(title: 'Exemple : EC sans Travaux Pratiques', values: ['Contrôle continu 30 %', 'Session normale 70 %'], formula: 'EC brut /100 = (CC × 0.30) + (SN × 0.70)')),
        ]),
        const SizedBox(height: 14),
        const Text('Calcul : arrondir chaque résultat d’EC à l’entier supérieur, puis calculer la moyenne des EC pondérée par leurs crédits. Arrondir ensuite ce résultat d’UE à l’entier supérieur pour déterminer son grade et ses points de MGP.'),
        const SizedBox(height: 14),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), color: const Color(0xFFF5E2DD), child: const Text('⚠ Le minimum annuel de 35/100 (7/20) concerne le résultat arrondi de chaque UE. Une évaluation CC, TP ou SN sous 7/20 ne déclenche pas EL. EL désigne une absence au rattrapage et empêche l’admission annuelle.', style: TextStyle(color: red))),
      ]);
}

class _MgpRules extends StatelessWidget {
  const _MgpRules();
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('La Moyenne Générale Pondérée synthétise les performances académiques de l’étudiant pour un semestre ou l’ensemble d’un cursus.'),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ink.withOpacity(.12))), child: const Center(child: Text('MGP =  Σ (Xi × ni)\n          ─────────\n             Σ ni', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontSize: 25, color: ink))))),
          const SizedBox(width: 16),
          const Expanded(child: Column(children: [_GuideCard(title: 'Xi : points de l’UE', text: 'Points du grade de la note entière de l’UE. Une UE EL vaut 0 point.'), _GuideCard(title: 'ni : crédits de l’UE', text: 'Crédits associés à l’unité d’enseignement.'), _GuideCard(title: 'Σ ni : crédits de la période', text: 'Total des crédits des UE dont l’inscription est validée, y compris les UE non acquises et les UE EL.')])),
        ]),
        const SizedBox(height: 14),
        const Text('Admission annuelle : MGP ≥ 2/4, résultat arrondi de chaque UE ≥ 35/100 et aucune UE EL. Une MGP semestrielle ne constitue pas une décision d’admission annuelle.'),
      ]);
}

class _CycleRules extends StatelessWidget {
  const _CycleRules();
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [Expanded(child: _CycleCard(title: 'Cycle 1', subtitle: 'Licence (L1 · L2 · L3)', credits: '180 ECTS', text: 'Passage de L1 ou L2 selon les crédits acquis et la moyenne requise.')), SizedBox(width: 12), Expanded(child: _CycleCard(title: 'Cycle 2', subtitle: 'Master (M1 · M2)', credits: '120 ECTS', text: 'Validation des semestres et soutenance du mémoire de Master.')), SizedBox(width: 12), Expanded(child: _CycleCard(title: 'Cycle 3', subtitle: 'Doctorat (D1 · D2 · D3)', credits: '180 ECTS', text: 'Accès en thèse, validation annuelle et soutenance de thèse.'))]);
}

class _Glossary extends StatelessWidget {
  const _Glossary();
  @override
  Widget build(BuildContext context) => const Wrap(spacing: 12, runSpacing: 12, children: [_GlossaryCard(title: 'Unité d’Enseignement (UE)', text: 'Élément constitutif d’un parcours de formation.'), _GlossaryCard(title: 'Crédits ECTS', text: 'Unité de mesure du travail exigé de l’étudiant.'), _GlossaryCard(title: 'Capitalisation & Transfert', text: 'Une UE validée est acquise pour toujours.'), _GlossaryCard(title: 'Enjambement', text: 'Dispositif permettant à un étudiant ayant validé au moins 75 % des crédits de continuer.'), _GlossaryCard(title: 'Relevé de Notes & Crédits', text: 'Document administratif certifié délivré par la faculté.'), _GlossaryCard(title: 'Session 2 (Rattrapage)', text: 'Session organisée pour les matières non validées.')] );
}

class _SupportContent extends StatelessWidget {
  const _SupportContent();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Consultation du Registre Centralisé des Notes', style: TextStyle(fontFamily: 'Fraunces', fontSize: 25, color: ink)),
        const SizedBox(height: 8),
        const Text('Vérifiez l’état d’enregistrement des procès-verbaux, les publications par Unité d’Enseignement et les mentions portées au registre officiel de délibération.'),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bordereau de réclamation PDF prêt à être téléchargé.'))), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Bordereau Réclamation (PDF)')),
          const SizedBox(width: 12),
          FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complétez le formulaire de requête ci-dessous.'))), icon: const Icon(Icons.edit_note), label: const Text('Déposer une requête')),
        ]),
        const SizedBox(height: 16),
        const _DeadlineBox(),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _RegistryForm()), const SizedBox(width: 18), const Expanded(child: _SupportAside())]),
        const SizedBox(height: 24),
        const Text('Dépôt d’une Requête de Délibération ou Rectification', style: TextStyle(fontFamily: 'Fraunces', fontSize: 25, color: ink)),
        const SizedBox(height: 8),
        const Text('Ce formulaire permet aux étudiants et délégués de signaler une anomalie matérielle constatée sur le relevé de notes ou le procès-verbal de session.'),
        const SizedBox(height: 16),
        const _RequestForm(),
      ]);
}

class _DeadlineBox extends StatelessWidget { const _DeadlineBox(); @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: red), color: paperLight), child: const Text('RÈGLE STRICTE DES DÉLAIS DE RÉCLAMATION DE NOTES\nLes contestations doivent être soumises dans un délai strict de 72 heures ouvrées suivant l’affichage officiel des procès-verbaux de délibération.', style: TextStyle(color: red))); }
class _RegistryForm extends StatelessWidget {
  const _RegistryForm();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recherche dans le registre', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, color: ink)),
            const SizedBox(height: 14),
            const Row(children: [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Matricule étudiant', hintText: 'Ex. 21A123', filled: true, fillColor: paperLight))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Code Unité (UE)', hintText: 'Ex. INF301', filled: true, fillColor: paperLight))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Cycle / niveau', hintText: 'Licence 3 (L3)', filled: true, fillColor: paperLight))),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recherche du registre lancée.'))), icon: const Icon(Icons.search), label: const Text('Consulter le registre')),
            const Divider(height: 28),
            const _RegisterLine(code: 'REG-2024-L3-084', label: 'INF301 · Algorithmique avancée · 6 crédits · 60h CM/TD', status: 'Scellé & homologué'),
            const _RegisterLine(code: 'REG-2024-L3-085', label: 'INF305 · Systèmes d’exploitation & Réseaux · 6 crédits', status: 'Période recours (48h)'),
            const _RegisterLine(code: 'REG-2024-L3-086', label: 'MAT311 · Probabilités & Statistiques LMD · 4 crédits', status: 'Scellé & homologué'),
            const _RegisterLine(code: 'REG-2024-L3-089', label: 'ENG300 · Anglais Technique & Rédaction · 2 crédits', status: 'Scellé & homologué'),
          ]),
        ),
      );
}
class _RegisterLine extends StatelessWidget { final String code, label, status; const _RegisterLine({required this.code, required this.label, required this.status}); @override Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, title: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)), subtitle: Text(label), trailing: Text(status, style: const TextStyle(color: valid, fontSize: 11))); }
class _SupportAside extends StatelessWidget {
  const _SupportAside();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('PERMANENCE JURY', style: TextStyle(fontFamily: 'monospace', color: red, fontSize: 11)),
            SizedBox(height: 8),
            Text('Cellule des Examens & Notes', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, color: ink)),
            Divider(),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.account_balance_outlined), title: Text('Secrétariat Académique Central'), subtitle: Text('Bâtiment Administratif Décanat · Bureau 104')),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.schedule), title: Text('Horaires d’ouverture des registres'), subtitle: Text('Lundi – Vendredi · 08h30 – 15h30')),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.mail_outline), title: Text('Courriel officiel d’assistance'), subtitle: Text('support.lmd@univ-gnu.edu')),
            Divider(),
            Text('DOCUMENTS & REGISTRES TYPES', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined, color: red), title: Text('Bordereau de PV de Délibération'), trailing: Text('PDF · 140 Ko')),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.picture_as_pdf_outlined, color: red), title: Text('Formulaire de Rectification Matérielle'), trailing: Text('PDF · 95 Ko')),
            ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.table_chart_outlined, color: red), title: Text('Fiche d’Émargement Travaux Pratiques'), trailing: Text('XLSX · 65 Ko')),
            Divider(),
            Text('SERVEUR ACADÉMIQUE GNU', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
            SizedBox(height: 6),
            Text('● 100% Opérationnel', style: TextStyle(color: valid, fontFamily: 'monospace')),
          ]),
        ),
      );
}
class _RequestForm extends StatelessWidget {
  const _RequestForm();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            const Row(children: [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Matricule universitaire *', hintText: '21A123', filled: true, fillColor: paperLight))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Nom complet de l’étudiant *', hintText: 'Ex. NDJOCK Jean-Baptiste', filled: true, fillColor: paperLight))),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Unité d’enseignement concernée *', hintText: 'INF305 · Systèmes d’exploitation', filled: true, fillColor: paperLight))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Composante contestée *', hintText: 'Travaux Pratiques (TP – 30%)', filled: true, fillColor: paperLight))),
              SizedBox(width: 12),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'Note affichée / présumée', hintText: 'Affiché : 06/20 · Évalué : 14/20', filled: true, fillColor: paperLight))),
            ]),
            const SizedBox(height: 12),
            const TextField(maxLines: 4, decoration: InputDecoration(labelText: 'Motif explicatif du recours académique *', hintText: 'Décrivez succinctement l’anomalie constatée : présence émargée, erreur d’addition ou note non reportée…', filled: true, fillColor: paperLight)),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requête transmise au Secrétariat du Jury.'))), icon: const Icon(Icons.send), label: const Text('Transmettre au Secrétariat du Jury'))),
          ]),
        ),
      );
}
class _StatusChip extends StatelessWidget { final String label; const _StatusChip({required this.label}); @override Widget build(BuildContext context) => Chip(label: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)), backgroundColor: paperLight); }
class _RuleCard extends StatelessWidget { final String title, formula; final List<String> values; const _RuleCard({required this.title, required this.values, required this.formula}); @override Widget build(BuildContext context) => Card(color: paperLight, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: values.map((v) => Chip(label: Text(v, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)))).toList()), const SizedBox(height: 10), Text(formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate))]))); }
class _CycleCard extends StatelessWidget { final String title, subtitle, credits, text; const _CycleCard({required this.title, required this.subtitle, required this.credits, required this.text}); @override Widget build(BuildContext context) => Card(color: paperLight, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', color: gold, fontSize: 11)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 17)), const SizedBox(height: 8), Text(credits, style: const TextStyle(fontFamily: 'monospace', color: valid)), const SizedBox(height: 12), Text(text)]))); }
class _GlossaryCard extends StatelessWidget { final String title, text; const _GlossaryCard({required this.title, required this.text}); @override Widget build(BuildContext context) => SizedBox(width: 350, child: Card(color: paperLight, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 5), Text(text, style: const TextStyle(color: slate))])))); }

class _SimplePage extends StatelessWidget {
  final String title, eyebrow, action; final VoidCallback onAction; final List<Widget> children;
  const _SimplePage({required this.title, required this.eyebrow, required this.action, required this.onAction, required this.children});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GnuBrand(),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Authentification')),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidePage())), child: const Text('Guide & Normes LMD')),
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())), child: const Text('Support & Registres')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: const TextStyle(fontFamily: 'monospace', color: red, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 18),
                ...children,
                const SizedBox(height: 28),
                FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.edit_note), label: Text(action)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget { final String title, text; const _GuideCard({required this.title, required this.text}); @override Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.menu_book_outlined, color: red), title: Text(title, style: Theme.of(context).textTheme.titleLarge), subtitle: Text(text))); }
class _LoginFeatureRow extends StatelessWidget { const _LoginFeatureRow(); @override Widget build(BuildContext context) => const Row(children: [_LoginFeature(icon: Icons.fact_check_outlined, title: 'Saisie Sécurisée', text: 'Saisie fluide et guidée des notes.'), _LoginFeature(icon: Icons.balance_outlined, title: 'Délibérations LMD', text: 'Application rigoureuse des règles LMD.'), _LoginFeature(icon: Icons.workspace_premium_outlined, title: 'Relevés Officiels', text: 'Édition instantanée des relevés.') ]); }
class _LoginFeature extends StatelessWidget {
  final IconData icon; final String title, text;
  const _LoginFeature({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(icon, color: red),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 5), Text(text, style: const TextStyle(color: slate))])),
              ],
            ),
          ),
        ),
      );
}
class _LoginFooter extends StatelessWidget { const _LoginFooter(); @override Widget build(BuildContext context) => const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('GNU — Gestion des Notes Universitaires', style: TextStyle(fontFamily: 'Fraunces', color: ink)), Text('Année Universitaire 2024–2025   ·   Assistance & Support', style: TextStyle(color: slate))]); }

class RoleHome extends StatelessWidget {
  final Role role;
  const RoleHome({super.key, required this.role});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: GnuBrand(),
          actions: [
            if (role == Role.etudiant) const _StudentNavActions(),
            if (role == Role.enseignant) const _TeacherNavActions(),
            TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())), child: const Text('Déconnexion')),
          ],
        ),
        body: switch (role) {
          Role.etudiant => const StudentDashboard(),
          Role.enseignant => const TeacherDashboard(),
          Role.cellule => const CelluleDashboard(),
        },
      );
}

class _StudentNavActions extends StatelessWidget {
  const _StudentNavActions();
  void later(BuildContext context, String label) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label sera activé à l’étape suivante.')));
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnrollmentPage())), icon: const Icon(Icons.assignment_outlined, size: 17), label: const Text('Inscription pédagogique')),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage())), icon: const Icon(Icons.star_border, size: 17), label: const Text('Notes & bulletins')),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage())), icon: const Icon(Icons.question_mark_outlined, size: 17), label: const Text('Mes requêtes')),
        const SizedBox(width: 8),
      ]);
}

class _TeacherNavActions extends StatelessWidget {
  const _TeacherNavActions();
  void later(BuildContext context, String label) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label sera construit à l’étape suivante.')));
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
        TextButton.icon(onPressed: () => later(context, 'Unités d’enseignement'), icon: const Icon(Icons.menu_book_outlined, size: 17), label: const Text('Unités d’enseignement')),
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GradeEntryPage())), icon: const Icon(Icons.fact_check_outlined, size: 17), label: const Text('Saisie et vérifications des notes')),
        TextButton.icon(onPressed: () => later(context, 'Requêtes'), icon: const Icon(Icons.campaign_outlined, size: 17), label: const Text('Requêtes')),
        const SizedBox(width: 8),
      ]);
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _StudentHero(onCertificate: () => _message(context, 'Certificat de scolarité prêt à être téléchargé.'), onTranscript: () => _message(context, 'Le relevé officiel sera généré à l’étape Notes & Bulletins.')),
              const SizedBox(height: 10),
              const _StudentIdentity(),
              const SizedBox(height: 16),
              const Row(children: [
                _StudentMetric(label: 'Crédits validés', value: '114', suffix: '/ 180 ECTS', note: '63.3% complété (L1: 60/60 · L2: 54/60)', color: gold, icon: Icons.school_outlined),
                _StudentMetric(label: 'MGP cumulée', value: '2.84', suffix: '/ 4.00', note: 'Mention Assez Bien · Équiv. 13.28 / 20', color: red, icon: Icons.analytics_outlined),
                _StudentMetric(label: 'Inscriptions S5', value: '06', suffix: ' UEs · 30 ECTS', note: 'Session normale active · +1 UE en rattrapage', color: ink, icon: Icons.menu_book_outlined),
                _StudentMetric(label: 'Requête en cours', value: '01', suffix: ' en arbitrage', note: 'INF301 · Réclamation TP · 12 fév. 2025', color: pending, icon: Icons.assignment_late_outlined),
              ]),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _StudentAlert(title: 'RATTRAPAGE L2 OBLIGATOIRE', badge: 'Échéance : 15 Mars', text: 'L’inscription pédagogique pour l’UE INF201 (Algèbre & Systèmes) est ouverte. Vous devez impérativement valider votre choix avant le tirage des listes d’émargement.', action: 'Confirmer mon inscription au rattrapage', color: red, onPressed: () => _message(context, 'Ouverture de l’inscription au rattrapage INF201.'))),
                const SizedBox(width: 14),
                Expanded(child: _StudentAlert(title: 'PUBLICATION CONTRÔLE CONTINU S5', badge: 'Clôture requêtes : 24 Fév', text: 'Les procès-verbaux de contrôle continu et TP du semestre en cours sont provisoirement arrêtés. Les réclamations de saisie de notes s’effectuent via l’onglet Requêtes.', action: 'Consulter le calendrier des jurys', color: gold, onPressed: () => _message(context, 'Calendrier des jurys : publication en cours.'))),
              ]),
              const SizedBox(height: 22),
              _StudentGradesSection(onFilter: () => _message(context, 'Filtre des unités activé.'), onView: (code) => _message(context, 'Détails de $code.')),
              const SizedBox(height: 18),
              _StudentComplaint(onHistory: () => _message(context, 'Historique des réclamations.'), onRequest: () => _message(context, 'Formulaire de réclamation académique.')),
            ]),
          ),
        ),
      );

  static void _message(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _StudentHero extends StatelessWidget {
  final VoidCallback onCertificate, onTranscript;
  const _StudentHero({required this.onCertificate, required this.onTranscript});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(18, 18, 18, 16), decoration: BoxDecoration(color: paperLight, border: Border.all(color: red.withOpacity(.25)), borderRadius: BorderRadius.circular(12)), child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('●  SESSION ACADÉMIQUE EN COURS', style: TextStyle(fontFamily: 'monospace', color: valid, fontSize: 12, letterSpacing: 1)), SizedBox(height: 10), Text('Tableau de Bord de l’Étudiant', style: TextStyle(fontFamily: 'Fraunces', fontSize: 30, fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 8), Text('TCHOUENTCHOU K. Arnaud · Matricule : 21U2412 · Licence 3 Informatique (Système LMD)')])) ,
        OutlinedButton.icon(onPressed: onCertificate, icon: const Icon(Icons.description_outlined), label: const Text('Certificat de scolarité')),
        const SizedBox(width: 10),
        FilledButton.icon(onPressed: onTranscript, icon: const Icon(Icons.download_outlined), label: const Text('Relevé officiel (PDF)')),
      ]));
}

class _StudentIdentity extends StatelessWidget {
  const _StudentIdentity();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 14), child: Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PARCOURS, SPÉCIALITÉ & CYCLE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), SizedBox(height: 7), Text('Licence Informatique · Cycle L (Niveau 3)   |   Tronc Génie Logiciel', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), Divider(), Text('SEMESTRE ACTIF D’ENRÔLEMENT', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), SizedBox(height: 7), Text('Semestre 5 (6 Unités d’Enseignement actives · 30 ECTS)', style: TextStyle(color: red, fontWeight: FontWeight.bold))])),
        const SizedBox(width: 22),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STATUT ADMINISTRATIF ET PÉDAGOGIQUE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), SizedBox(height: 7), Text('◉ Régulier — Enrôlement complet validé', style: TextStyle(color: valid, fontWeight: FontWeight.bold)), Divider(), Text('DETTE ACADÉMIQUE RÉSIDUELLE (CRÉDIT L2)', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: red)), SizedBox(height: 7), Text('1 UE à rattraper : INF201 Algèbre & Systèmes numériques (6 ECTS)', style: TextStyle(fontWeight: FontWeight.bold, color: ink))])),
      ])));
}

class _StudentMetric extends StatelessWidget {
  final String label, value, suffix, note; final Color color; final IconData icon;
  const _StudentMetric({required this.label, required this.value, required this.suffix, required this.note, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), Icon(icon, size: 18, color: color)]), const SizedBox(height: 13), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 26, color: color)), const SizedBox(width: 5), Text(suffix, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate))]), const SizedBox(height: 8), Text(note, style: TextStyle(fontSize: 11, color: color))]))));
}

class _StudentAlert extends StatelessWidget {
  final String title, badge, text, action; final Color color; final VoidCallback onPressed;
  const _StudentAlert({required this.title, required this.badge, required this.text, required this.action, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) => Card(color: paperLight, shape: RoundedRectangleBorder(side: BorderSide(color: color.withOpacity(.45)), borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.assignment_late_outlined, color: color), const SizedBox(width: 10), Expanded(child: Text(title, style: TextStyle(fontFamily: 'monospace', color: color, fontWeight: FontWeight.bold, fontSize: 12))), Chip(label: Text(badge, style: TextStyle(color: color, fontSize: 10)), backgroundColor: color.withOpacity(.12))]), const SizedBox(height: 10), Text(text), const SizedBox(height: 10), TextButton.icon(onPressed: onPressed, icon: Icon(Icons.arrow_forward, color: color, size: 16), label: Text(action, style: TextStyle(color: color, fontWeight: FontWeight.bold)))])));
}

class _StudentGradesSection extends StatelessWidget {
  final VoidCallback onFilter; final void Function(String) onView;
  const _StudentGradesSection({required this.onFilter, required this.onView});
  @override
  Widget build(BuildContext context) => Card(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aperçu des cours et évaluations — Semestre 5', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.bold, color: ink)),
                SizedBox(height: 4),
                Text('Évaluations continues (CC), travaux pratiques (TP) et examens de la session normale.', style: TextStyle(fontSize: 12, color: slate)),
              ])),
              const Text('Affichage : 6 UEs inscrites', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: onFilter, child: const Text('Filtrer')),
            ]),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('CODE UE')), DataColumn(label: Text('INTITULÉ DE L’UNITÉ')), DataColumn(label: Text('CRÉDITS')), DataColumn(label: Text('CC /20')), DataColumn(label: Text('TP /20')), DataColumn(label: Text('EXAMEN SN')), DataColumn(label: Text('STATUT')), DataColumn(label: Text('ACTION')),
              ],
              rows: [
                _gradeRow('INF301', 'Conception Orientée Objet & Design Patterns', '5 ECTS', '14.50', '10.00*', 'À composer', 'Arbitrage', pending, onView),
                _gradeRow('INF303', 'Systèmes de Gestion de Bases de Données Avancées', '5 ECTS', '15.00', '16.50', 'À composer', 'En bonne voie', valid, onView),
                _gradeRow('INF305', 'Réseaux Informatiques & Protocoles Internet', '5 ECTS', '13.00', '14.00', 'À composer', 'En bonne voie', valid, onView),
                _gradeRow('INF307', 'Algorithmique Avancée & Complexité', '5 ECTS', '08.50', '—', 'À composer', 'À surveiller', red, onView),
                _gradeRow('MAT309', 'Recherche Opérationnelle & Optimisation Linéaire', '5 ECTS', '12.00', '—', 'À composer', 'En bonne voie', valid, onView),
                _gradeRow('HUM311', 'Anglais Professionnel & Éthique du Numérique', '5 ECTS', '16.00', '—', 'À composer', 'Validé prov.', valid, onView),
                _gradeRow('INF201*', 'Algèbre & Systèmes Numériques (Dette de niveau 2)', '6 ECTS', '09.25', '—', 'Rattrapage', 'Dette L2', red, onView),
              ],
            ),
          ),
        ]),
      );

  static DataRow _gradeRow(String code, String label, String credits, String cc, String tp, String exam, String status, Color color, void Function(String) onView) => DataRow(cells: [DataCell(Text(code, style: TextStyle(fontFamily: 'monospace', color: color))), DataCell(Text(label)), DataCell(Text(credits)), DataCell(Text(cc)), DataCell(Text(tp, style: TextStyle(color: tp.contains('*') ? gold : ink))), DataCell(Text(exam)), DataCell(Chip(label: Text(status, style: TextStyle(fontSize: 10, color: color)), backgroundColor: color.withOpacity(.12))), DataCell(IconButton(onPressed: () => onView(code), icon: const Icon(Icons.visibility_outlined, size: 18)))]);
}

class _StudentComplaint extends StatelessWidget {
  final VoidCallback onHistory, onRequest;
  const _StudentComplaint({required this.onHistory, required this.onRequest});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Icon(Icons.assignment_late_outlined, color: red, size: 30), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Une anomalie constatée sur votre relevé provisoire ?', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 5), Text('Déposez une requête académique justificative avant la tenue du jury de fin de semestre.', style: TextStyle(color: slate))])), OutlinedButton.icon(onPressed: onHistory, icon: const Icon(Icons.history), label: const Text('Historique des réclamations')), const SizedBox(width: 10), FilledButton.icon(onPressed: onRequest, icon: const Icon(Icons.description_outlined), label: const Text('Déposer une réclamation'))])));
}

class EnrollmentPage extends StatefulWidget {
  const EnrollmentPage({super.key});
  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  String selectedOption = 'INF309';
  bool validated = false;

  void choose(String code) => setState(() => selectedOption = code);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: GnuBrand(),
          actions: [
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.assignment_outlined, size: 17), label: const Text('Inscription pédagogique')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage())), icon: const Icon(Icons.star_border, size: 17), label: const Text('Notes & bulletins')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage())), icon: const Icon(Icons.question_mark_outlined, size: 17), label: const Text('Mes requêtes')),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _EnrollmentHeader(),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final main = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _DebtCard(),
                    const SizedBox(height: 18),
                    const _FundamentalUnits(),
                    const SizedBox(height: 18),
                    _OptionalUnits(selectedCode: selectedOption, onSelected: choose),
                  ]);
                  final summary = _EnrollmentSummary(validated: validated, onValidate: () => setState(() => validated = true));
                  return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: main), const SizedBox(width: 18), SizedBox(width: 320, child: summary)]) : Column(children: [main, const SizedBox(height: 18), summary]);
                }),
                const SizedBox(height: 28),
                const _StudentFooter(),
              ]),
            ),
          ),
        ),
      );
}

class _EnrollmentHeader extends StatelessWidget {
  const _EnrollmentHeader();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RÉGIME ORDINAIRE · LICENCE 3 SEMESTRE 5 (S5) · ANNÉE 2024–2025', style: TextStyle(fontFamily: 'monospace', color: red, letterSpacing: 1.2, fontSize: 12)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Inscription Pédagogique & Choix des UEs', style: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 27, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Sélection semestrielle des Unités d’Enseignement (UE) et Éléments Constitutifs (EC). Quota réglementaire : 30 Crédits ECTS par semestre.')])) ,
          const SizedBox(width: 22),
          Container(width: 350, padding: const EdgeInsets.all(14), color: paper, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('STATUT D’ENRÔLEMENT', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 11)), SizedBox(height: 8), Chip(label: Text('◉ Étudiant Régulier avec Dette L2 autorisée'), backgroundColor: Color(0xFF8C2F2F), labelStyle: TextStyle(color: Colors.white, fontSize: 11)), SizedBox(height: 4), Text('○ Étudiant Régulier Standard (30 ECTS)    ○ Redoublant / Régime Particulier', style: TextStyle(fontSize: 10, color: slate))])),
        ]),
        const Divider(height: 26),
        Row(children: [const Text('✓  Total des crédits sélectionnés :', style: TextStyle(fontWeight: FontWeight.bold, color: valid)), const SizedBox(width: 30), const Text('30 / 30 ECTS', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold)), const SizedBox(width: 28), const Text('(Objectif semestre 5 atteint)', style: TextStyle(color: valid)), const Spacer(), Container(width: 280, height: 10, decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(4)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: .82, child: Container(color: ink))),]),
      ])));
}

class _DebtCard extends StatelessWidget {
  const _DebtCard();
  @override
  Widget build(BuildContext context) => Card(shape: RoundedRectangleBorder(side: const BorderSide(color: gold), borderRadius: BorderRadius.circular(6)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.priority_high, color: gold), const SizedBox(width: 10), const Expanded(child: Text('Reprise obligatoire de dette antérieure non capitalisée (Semestre 4 / L2)', style: TextStyle(fontFamily: 'Fraunces', fontSize: 18, fontWeight: FontWeight.bold, color: ink))), Chip(label: const Text('RÉGLEMENTATION LMD · PRIORITÉ 1'), backgroundColor: gold.withOpacity(.18), labelStyle: const TextStyle(color: gold, fontSize: 10))]),
        const SizedBox(height: 5),
        const Text('En application de la réglementation LMD, l’inscription à la dette est prioritaire sur les UEs optionnelles du niveau en cours.'),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), color: paper, child: const Row(children: [Icon(Icons.check_box, color: valid), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('INF201  Algèbre Linéaire & Systèmes Numériques', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 5), Text('Session Ordinaire S4 : 07.50 / 20   ·   Volume : 45 Heures', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), SizedBox(height: 5), Text('Coordonnateur : Dr. MVONDO G.   ·   Semestre d’origine : S4 (L2)', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: red))])), Text('6 ECTS', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold))])),
      ])));
}

class _FundamentalUnits extends StatelessWidget {
  const _FundamentalUnits();
  static const units = [('INF301', 'Génie Logiciel & Architecture Web', '6 ECTS', 'Responsable : Pr. ETOUNDI J.'), ('INF303', 'Bases de Données Avancées & NoSQL', '6 ECTS', 'Responsable : Dr. BELLA C.'), ('INF305', 'Réseaux Informatiques & Protocoles IP', '5 ECTS', 'Responsable : M. NGATCHOU F.'), ('INF307', 'Programmation Système & Concurrente', '5 ECTS', 'Responsable : Dr. TSOPMO A.')];
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('◈  Unités d’Enseignement Fondamentales (Obligatoires)', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 4), const Text('Tronc commun de spécialité de Licence 3 Informatique pour le Semestre 5.'), const Divider(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: ink, child: const Text('▣  22 ECTS Obligatoires cochés d’office', style: TextStyle(color: paperLight, fontFamily: 'monospace', fontSize: 11))), const SizedBox(height: 8), ...units.map((unit) => _UnitTile(code: unit.$1, title: unit.$2, credits: unit.$3, details: unit.$4, required: true))])));
}

class _OptionalUnits extends StatelessWidget {
  final String selectedCode; final ValueChanged<String> onSelected;
  const _OptionalUnits({required this.selectedCode, required this.onSelected});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('☷  Unités d’Enseignement Complémentaires / Optionnelles', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 5), const Text('Choisissez exactement 1 unité d’enseignement parmi les options ci-dessous pour compléter votre quota de 30 ECTS.'), const SizedBox(height: 12), const Chip(label: Text('1 UE au choix requise (4 ECTS)'), backgroundColor: Color(0xFFF1E1C4), labelStyle: TextStyle(color: gold)), const SizedBox(height: 8), _SelectableUnit(code: 'INF309', title: 'Intelligence Artificielle & Aide à la Décision', details: 'Vol: 40h (CM: 20h · TD: 10h · TP: 10h) · Responsable : Pr. TCHOUENTCHOU M.', selected: selectedCode == 'INF309', onTap: () => onSelected('INF309')), _SelectableUnit(code: 'INF311', title: 'Sécurité des Systèmes d’Information & Cryptographie', details: 'Vol: 40h (CM: 20h · TD: 10h · TP: 10h) · Responsable : Dr. ESSOMBA L.', selected: selectedCode == 'INF311', onTap: () => onSelected('INF311')), _SelectableUnit(code: 'HUM301', title: 'Éthique, Droit du Numérique & Brevets', details: 'Vol: 40h (CM: 30h · TD: 10h) · Responsable : Mme FOE B.', selected: selectedCode == 'HUM301', onTap: () => onSelected('HUM301'))])));
}

class _UnitTile extends StatelessWidget {
  final String code, title, credits, details; final bool required;
  const _UnitTile({required this.code, required this.title, required this.credits, required this.details, required this.required});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: paper, border: Border.all(color: ink.withOpacity(.12)), borderRadius: BorderRadius.circular(5)), child: Row(children: [Icon(required ? Icons.check_box : Icons.radio_button_unchecked, color: required ? valid : slate), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$code  $title', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 4), Text(details, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), const SizedBox(height: 4), Text(required ? 'Inscrit d’office' : 'Non sélectionné', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: required ? valid : slate))])), Text(credits, style: const TextStyle(fontFamily: 'monospace', color: ink))]));
}

class _SelectableUnit extends StatelessWidget {
  final String code, title, details; final bool selected; final VoidCallback onTap;
  const _SelectableUnit({required this.code, required this.title, required this.details, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: selected ? const Color(0xFFF4F7EF) : paper, border: Border.all(color: selected ? valid : ink.withOpacity(.14), width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(5)), child: Row(children: [Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? valid : slate), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$code  $title', style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 5), Text(details, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), const SizedBox(height: 5), Text(selected ? '✓ SÉLECTIONNÉ POUR LE PARCOURS GÉNIE LOGICIEL' : 'Non sélectionné', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: selected ? valid : slate))])), const Text('4 ECTS', style: TextStyle(fontFamily: 'monospace', color: ink, fontWeight: FontWeight.bold))])));
}

class _EnrollmentSummary extends StatelessWidget {
  final bool validated; final VoidCallback onValidate;
  const _EnrollmentSummary({required this.validated, required this.onValidate});
  @override
  Widget build(BuildContext context) => Card(shape: RoundedRectangleBorder(side: BorderSide(color: validated ? valid : ink.withOpacity(.35))), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DOCUMENT RÉGLEMENTAIRE', style: TextStyle(fontFamily: 'monospace', color: slate, fontSize: 10)), const SizedBox(height: 6), const Text('Bordereau Provisoire d’Enrôlement S5', style: TextStyle(fontFamily: 'Fraunces', fontSize: 20, fontWeight: FontWeight.bold, color: ink)), const Divider(), const _SummaryLine(label: 'UEs fondamentales (Tronc Commun)', value: '22 ECTS'), const _SummaryLine(label: 'Reprise Dette L2 (INF201)', value: '6 ECTS'), const _SummaryLine(label: 'UE Optionnelle', value: '4 ECTS'), const Divider(), const _SummaryLine(label: 'TOTAL DES CRÉDITS ENRÔLÉS', value: '30 / 30 ECTS', strong: true), const SizedBox(height: 14), Container(padding: const EdgeInsets.all(10), color: paper, child: const Text('Volume horaire total présentiel : 280 heures\nDétail : CM 124h · TD 62h · TP 94h', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))), const SizedBox(height: 12), const Text('⚠ Avertissement académique : la validation pédagogique est définitive après visa du Coordonnateur de filière.', style: TextStyle(color: red, fontSize: 11)), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onValidate, icon: Icon(validated ? Icons.verified : Icons.verified_outlined), label: Text(validated ? 'INSCRIPTION VALIDÉE' : 'Valider définitivement mon inscription'))), const SizedBox(height: 8), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche d’inscription PDF prête.'))), icon: const Icon(Icons.download_outlined), label: const Text('Télécharger la fiche (.PDF'))), const SizedBox(height: 10), Center(child: Text(validated ? '✓ Registre des visas mis à jour' : 'Réinitialiser les options', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: validated ? valid : slate)))])));
}

class _SummaryLine extends StatelessWidget {
  final String label, value; final bool strong;
  const _SummaryLine({required this.label, required this.value, this.strong = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: strong ? FontWeight.bold : FontWeight.normal))), Text(value, style: TextStyle(fontFamily: 'monospace', color: strong ? red : ink, fontWeight: strong ? FontWeight.bold : FontWeight.normal))]));
}

class _StudentFooter extends StatelessWidget {
  const _StudentFooter();
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), color: paperLight, child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('GNU — Gestion des Notes Universitaires', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink)), Text('ANNÉE UNIVERSITAIRE 2024–2025   ·   ASSISTANCE & SUPPORT', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]));
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  String year = '2024–2025';
  String period = 'S5 · En cours';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: GnuBrand(),
          actions: [
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnrollmentPage())), icon: const Icon(Icons.assignment_outlined, size: 17), label: const Text('Inscription pédagogique')),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.star_border, size: 17), label: const Text('Notes & bulletins')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage())), icon: const Icon(Icons.question_mark_outlined, size: 17), label: const Text('Mes requêtes')),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _NotesHeader(year: year, period: period, onYear: (v) => setState(() => year = v), onPeriod: (v) => setState(() => period = v), onExport: () => _notice(context, 'Export Excel prêt à être téléchargé.'), onPdf: () => _notice(context, 'Bulletin officiel PDF prêt à être téléchargé.')),
                const SizedBox(height: 18),
                const Row(children: [
                  _NotesMetric(label: 'Moyenne semestrielle', value: '14.15', suffix: '/20.00', note: '↑ +0.82 pts vs Semestre 4', color: ink),
                  _NotesMetric(label: 'Moyenne pondérée (MGP)', value: '3.12', suffix: '/4.00', note: 'Système nord-américain équiv. B+', color: ink),
                  _NotesMetric(label: 'Rang de promotion', value: '04ème', suffix: '/ 142 inscrits', note: 'Top 2.8% de la cohorte L3', color: red),
                  _NotesMetric(label: 'Crédits ECTS capitalisés', value: '30', suffix: '/30 ECTS', note: 'Semestre complet validé', color: valid),
                  _NotesMetric(label: 'Mention & évaluation', value: 'BIEN', suffix: '', note: 'Barème légal 14.00 – 15.99', color: ink),
                  _NotesMetric(label: 'Délibération jury', value: 'ADMIS', suffix: '', note: 'Session normale certifiée', color: valid),
                ]),
                const SizedBox(height: 18),
                _NotesRegister(onRequest: () => _notice(context, 'La requête académique sera disponible dans l’écran Mes Requêtes.')),
                const SizedBox(height: 18),
                const _NotesInformation(),
                const SizedBox(height: 24),
                const _StudentFooter(),
              ]),
            ),
          ),
        ),
      );

  static void _notice(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _NotesHeader extends StatelessWidget {
  final String year, period; final ValueChanged<String> onYear, onPeriod; final VoidCallback onExport, onPdf;
  const _NotesHeader({required this.year, required this.period, required this.onYear, required this.onPeriod, required this.onExport, required this.onPdf});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        const Text('ANNÉE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), const SizedBox(width: 8),
        ...['2024–2025', '2023–2024', '2022–2023'].map((v) => Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text(v, style: const TextStyle(fontSize: 11)), selected: year == v, onSelected: (_) => onYear(v)))),
        const SizedBox(width: 18), const Text('PÉRIODE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)), const SizedBox(width: 8),
        ...['S5 · En cours', 'S4 · Validé', 'S3 · Validé', 'S2 · Validé'].map((v) => Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text(v, style: const TextStyle(fontSize: 11)), selected: period == v, onSelected: (_) => onPeriod(v)))),
        const Spacer(),
        OutlinedButton.icon(onPressed: onExport, icon: const Icon(Icons.table_view_outlined), label: const Text('Exporter (.xlsx)')), const SizedBox(width: 8),
        FilledButton.icon(onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Bulletin Officiel (.pdf)')),
      ])));
}

class _NotesMetric extends StatelessWidget {
  final String label, value, suffix, note; final Color color;
  const _NotesMetric({required this.label, required this.value, required this.suffix, required this.note, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), const SizedBox(height: 12), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: TextStyle(fontFamily: 'Fraunces', fontSize: 25, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 4), Text(suffix, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]), const SizedBox(height: 9), Text(note, style: TextStyle(fontSize: 10, color: color))]))));
}

class _NotesRegister extends StatelessWidget {
  final VoidCallback onRequest;
  const _NotesRegister({required this.onRequest});
  @override
  Widget build(BuildContext context) => Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 12), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Grand Registre des Notes & Évaluations', style: TextStyle(fontFamily: 'Fraunces', fontSize: 23, fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 5), Text('Relevé officiel des Unités d’Enseignement (UE) et éléments constitutifs (EC) · Semestre 5', style: TextStyle(color: slate, fontSize: 12))])), const Chip(label: Text('● 5 UE Validées'), backgroundColor: Color(0xFFE0EADF), labelStyle: TextStyle(color: valid, fontSize: 10)), const SizedBox(width: 5), const Chip(label: Text('● 1 Dette sous tutorat'), backgroundColor: Color(0xFFF1E1C4), labelStyle: TextStyle(color: gold, fontSize: 10))])), const Divider(height: 1), SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 23, columns: const [DataColumn(label: Text('CODE UE')), DataColumn(label: Text('MATIÈRE & ENSEIGNANT')), DataColumn(label: Text('CC (20%)')), DataColumn(label: Text('TP (30%)')), DataColumn(label: Text('SN (50%)')), DataColumn(label: Text('MOY. /20')), DataColumn(label: Text('NOTE/100')), DataColumn(label: Text('GRADE')), DataColumn(label: Text('POINTS')), DataColumn(label: Text('CRÉDITS')), DataColumn(label: Text('STATUT / DÉCISION'))], rows: const [
        DataRow(cells: [DataCell(Text('INF301', style: TextStyle(color: red))), DataCell(Text('Algorithmique Avancée & Complexité\nPr. F. MBARGA')), DataCell(Text('14.00')), DataCell(Text('16.00\nRectifié')), DataCell(Text('15.50')), DataCell(Text('15.35')), DataCell(Text('76.75')), DataCell(Text('B+')), DataCell(Text('3.30')), DataCell(Text('6')), DataCell(Text('✓ VALIDÉ'))]),
        DataRow(cells: [DataCell(Text('INF302', style: TextStyle(color: red))), DataCell(Text('Systèmes d’Exploitation & Noyaux Unix\nDr. H. NKENGFACK')), DataCell(Text('12.50')), DataCell(Text('15.00')), DataCell(Text('13.00')), DataCell(Text('13.50')), DataCell(Text('67.50')), DataCell(Text('B')), DataCell(Text('3.00')), DataCell(Text('6')), DataCell(Text('✓ VALIDÉ'))]),
        DataRow(cells: [DataCell(Text('INF303', style: TextStyle(color: red))), DataCell(Text('Bases de Données Relationnelles & NoSQL\nPr. J. BELA KOUAM')), DataCell(Text('16.00')), DataCell(Text('17.50')), DataCell(Text('15.00')), DataCell(Text('15.95')), DataCell(Text('79.75')), DataCell(Text('A−')), DataCell(Text('3.70')), DataCell(Text('6')), DataCell(Text('✓ VALIDÉ'))]),
        DataRow(cells: [DataCell(Text('INF304', style: TextStyle(color: red))), DataCell(Text('Génie Logiciel & Modélisation UML\nDr. S. KAMGANG')), DataCell(Text('11.00')), DataCell(Text('14.00')), DataCell(Text('12.50')), DataCell(Text('12.65')), DataCell(Text('63.25')), DataCell(Text('B−')), DataCell(Text('2.70')), DataCell(Text('4')), DataCell(Text('✓ VALIDÉ'))]),
        DataRow(cells: [DataCell(Text('ANG301', style: TextStyle(color: red))), DataCell(Text('Anglais Technique & Communication\nMme A. FORBIN')), DataCell(Text('15.00')), DataCell(Text('—')), DataCell(Text('16.00')), DataCell(Text('15.70')), DataCell(Text('78.50')), DataCell(Text('B+')), DataCell(Text('3.30')), DataCell(Text('4')), DataCell(Text('✓ VALIDÉ'))]),
        DataRow(cells: [DataCell(Text('INF201', style: TextStyle(color: red))), DataCell(Text('Algèbre Linéaire & Calcul Matriciel (Reprise)\nDépartement Mathématiques')), DataCell(Text('—/20')), DataCell(Text('—')), DataCell(Text('—/20')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('—')), DataCell(Text('4')), DataCell(Text('◷ EN COURS'))]),
      ]))]));
}

class _NotesInformation extends StatelessWidget {
  const _NotesInformation();
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [Expanded(child: _InfoCard(title: 'Barème Officiel de Conversion LMD', icon: Icons.gavel_outlined, text: '80–100 : A · 4.00 · Très Bien\n75–79.9 : B+ · 3.30 · Bien\n65–69.9 : B− · 2.70 · Assez Bien\n< 50 : F · 0.00 · Échec / Rattrapage')), SizedBox(width: 14), Expanded(child: _InfoCard(title: 'Légende & Règles de Calcul', icon: Icons.info_outline, text: 'CC : Contrôle Continu\nTP : Travaux Pratiques\nSN : Session Normale\nMGP : Moyenne Générale Pondérée\nCOMP : Compensation autorisée si moyenne du bloc UE ≥ 10/20.')), SizedBox(width: 14), Expanded(child: _InfoCard(title: 'Certification & Décanat', icon: Icons.verified_user_outlined, text: 'Ce relevé semestriel a été validé par le Conseil de Délibération de la Faculté des Sciences en date du 18 Janvier 2025.\n\nSignature électronique : SHA256:48f89b...12C0'))]);
}

class _InfoCard extends StatelessWidget {
  final String title, text; final IconData icon;
  const _InfoCard({required this.title, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: gold), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 18, fontWeight: FontWeight.bold, color: ink)))]), const Divider(), Text(text, style: const TextStyle(fontSize: 12, color: slate, height: 1.5))])));
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  String ue = 'INF301 — Conception Orientée Objet';
  String nature = 'Contrôle Continu';
  String motif = 'Note de TP non reportée ou erreur matérielle';
  bool submitted = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: GnuBrand(),
          actions: [
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnrollmentPage())), icon: const Icon(Icons.assignment_outlined, size: 17), label: const Text('Inscription pédagogique')),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage())), icon: const Icon(Icons.star_border, size: 17), label: const Text('Notes & bulletins')),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.question_mark_outlined, size: 17), label: const Text('Mes requêtes')),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(children: [
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final form = _RequestFormPanel(ue: ue, nature: nature, motif: motif, onUe: (v) => setState(() => ue = v), onNature: (v) => setState(() => nature = v), onMotif: (v) => setState(() => motif = v), onSubmit: () => setState(() => submitted = true));
                  final aside = _RequestAside(submitted: submitted);
                  return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: form), const SizedBox(width: 22), SizedBox(width: 400, child: aside)]) : Column(children: [form, const SizedBox(height: 18), aside]);
                }),
                const SizedBox(height: 24),
                const _StudentFooter(),
              ]),
            ),
          ),
        ),
      );
}

class _RequestFormPanel extends StatelessWidget {
  final String ue, nature, motif; final ValueChanged<String> onUe, onNature, onMotif; final VoidCallback onSubmit;
  const _RequestFormPanel({required this.ue, required this.nature, required this.motif, required this.onUe, required this.onNature, required this.onMotif, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FORMULAIRE OFFICIEL  /  RÉF. DÉCRET ARBITRAGE LMD N° 2021–419', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: red, letterSpacing: .8)),
        const SizedBox(height: 8),
        const Text('Réclamation Académique & Arbitrage', style: TextStyle(fontFamily: 'Fraunces', fontSize: 28, color: red)),
        const SizedBox(height: 5),
        const Text('Registre d’instruction contradictoire pour la rectification des procès-verbaux de notes semestriels.', style: TextStyle(color: slate)),
        const SizedBox(height: 22),
        const Text('Unité d’Enseignement (UE) concernée *', style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: ue, decoration: const InputDecoration(filled: true, fillColor: paper, border: InputBorder.none), items: const [DropdownMenuItem(value: 'INF301 — Conception Orientée Objet', child: Text('INF301 — Conception Orientée Objet')), DropdownMenuItem(value: 'INF303 — Bases de Données', child: Text('INF303 — Bases de Données')), DropdownMenuItem(value: 'INF307 — Algorithmique Avancée', child: Text('INF307 — Algorithmique Avancée'))], onChanged: (v) { if (v != null) onUe(v); }),
        const SizedBox(height: 18),
        const Text('Nature de l’évaluation contestée *', style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
        Row(children: ['Contrôle Continu', 'Travaux Pratiques', 'Examen Terminal'].map((v) => Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, dense: true, title: Text(v, style: const TextStyle(fontSize: 12)), subtitle: Text(v == 'Contrôle Continu' ? 'Pondération 30%' : v == 'Travaux Pratiques' ? 'Session 1 à 6' : 'Session Normale 70%', style: const TextStyle(fontSize: 10)), value: v, groupValue: nature, onChanged: (x) { if (x != null) onNature(x); }))).toList()),
        const SizedBox(height: 10),
        const Text('Motif formel de la réclamation *', style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: motif, decoration: const InputDecoration(filled: true, fillColor: paper, border: InputBorder.none), items: const [DropdownMenuItem(value: 'Note de TP non reportée ou erreur matérielle', child: Text('Note de TP non reportée ou erreur matérielle')), DropdownMenuItem(value: 'Erreur de calcul ou d’addition', child: Text('Erreur de calcul ou d’addition')), DropdownMenuItem(value: 'Absence injustifiée / émargement', child: Text('Absence injustifiée / émargement'))], onChanged: (v) { if (v != null) onMotif(v); }),
        const SizedBox(height: 18),
        const Row(children: [Expanded(child: _ScoreBox(title: 'Note affichée sur le PV provisoire', value: 'ex: 00.00 ou 08.50', tag: 'Litigieuse')), SizedBox(width: 14), Expanded(child: _ScoreBox(title: 'Note réclamée / estimée', value: 'ex: 15.50', tag: 'Régularisation'))]),
        const SizedBox(height: 18),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Exposé méthodique des faits & argumentation', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), Text('0 / 600 car.', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]),
        const SizedBox(height: 6),
        const TextField(maxLines: 5, decoration: InputDecoration(filled: true, fillColor: paper, border: InputBorder.none, hintText: 'Exposez avec sobriété et courtoisie les circonstances : date de la composition, signature sur la feuille d’émargement, numéro de poste en salle machine ou confirmation orale de l’enseignant…')),
        const SizedBox(height: 18),
        const Text('Pièces justificatives probantes     Formats : PDF, JPG, PNG (Max 5 Mo)', style: TextStyle(fontWeight: FontWeight.bold, color: ink)),
        const SizedBox(height: 6),
        InkWell(onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélection de pièce jointe simulée.'))), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 30), color: paper, child: const Column(children: [Icon(Icons.attach_file, color: red, size: 28), SizedBox(height: 8), Text('Déposer la pièce justificative ou cliquer pour parcourir', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 4), Text('Copie de la feuille de présence émargée, barème visé ou copie du devoir.', style: TextStyle(fontSize: 11, color: slate))]))),
        const SizedBox(height: 18),
        Row(children: [const Expanded(child: Text('◉ La soumission attribue un identifiant de registre officiel scellé.', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))), FilledButton.icon(onPressed: onSubmit, icon: const Icon(Icons.send), label: const Text('Transmettre la requête au Bureau d’Arbitrage'))]),
      ])));
}

class _ScoreBox extends StatelessWidget {
  final String title, value, tag;
  const _ScoreBox({required this.title, required this.value, required this.tag});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), color: paper, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text(tag, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: valid))]), const SizedBox(height: 10), Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, color: ink))]));
}

class _RequestAside extends StatelessWidget {
  final bool submitted;
  const _RequestAside({required this.submitted});
  @override
  Widget build(BuildContext context) => Column(children: [Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(5)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('◷  DÉLAI LÉGAL D’ARBITRAGE', style: TextStyle(fontFamily: 'monospace', color: paperLight, fontSize: 11)), Chip(label: Text('72H OUVRABLES'), backgroundColor: Color(0x33FFFFFF), labelStyle: TextStyle(color: paperLight, fontSize: 10))]), SizedBox(height: 14), Text('Clôture des réclamations dans 38h 14m', style: TextStyle(fontFamily: 'Fraunces', fontSize: 21, color: paperLight)), SizedBox(height: 10), Text('Toute contestation des notes de la Session Normale S5 doit être soumise au plus tard le 27 Février 2025 à 18h00.', style: TextStyle(color: paper, fontSize: 12)), SizedBox(height: 14), Text('Commission décanale de régularisation :    03 Mars 2025', style: TextStyle(fontFamily: 'monospace', color: paperLight, fontSize: 10))])), const SizedBox(height: 18), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.history, color: ink), SizedBox(width: 8), Text('Historique & Suivi des Requêtes', style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, fontWeight: FontWeight.bold, color: ink))]), const Divider(), _RequestHistoryItem(code: 'REQ-2025-0842', title: 'INF301 — Travaux Pratiques Machine', status: submitted ? 'REQUÊTE TRANSMISE' : 'EN ATTENTE D’ARBITRAGE', color: pending, detail: 'Motif : omission de la note du TP n°4 lors de l’export centralisé.'), const SizedBox(height: 10), const _RequestHistoryItem(code: 'REQ-2024-0319', title: 'INF202 — Architecture des Ordinateurs', status: 'RECTIFIÉE & VALIDÉE', color: valid, detail: 'Résolution : +3.50 points accordés après vérification décanale.'), const SizedBox(height: 14), Container(padding: const EdgeInsets.all(12), color: paper, child: const Text('Besoin d’un arbitrage en séance plénière ?\nFormulez une demande gracieuse devant le Conseil Pédagogique Décanal.', style: TextStyle(fontSize: 11, color: slate))) ])))]);
}

class _RequestHistoryItem extends StatelessWidget {
  final String code, title, status, detail; final Color color;
  const _RequestHistoryItem({required this.code, required this.title, required this.status, required this.color, required this.detail});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), color: paper, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), Text(status, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: color, fontWeight: FontWeight.bold))]), const SizedBox(height: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 5), Text(detail, style: const TextStyle(fontSize: 11, color: slate)), const SizedBox(height: 5), Text('Consulter le récépissé →', style: TextStyle(fontSize: 11, color: color))]));
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _TeacherContext(),
              const SizedBox(height: 18),
              const _TeacherHero(),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _TeacherPillar(title: 'PILIER 1', heading: 'Unités d’Enseignement', badge: '3 Cours Affectés', value: '310', caption: 'Étudiants au total', color: ink, icon: Icons.menu_book_outlined, lines: const ['INF301 · Algorithmique Avancée', 'INF305 · Systèmes & Réseaux', 'INF201 · Programmation C/C++'], action: 'Gérer les Unités d’enseignement', onPressed: () => _notice(context, 'La gestion des UE sera construite à l’étape suivante.'))),
                const SizedBox(width: 18),
                Expanded(child: _TeacherPillar(title: 'PILIER 2', heading: 'Saisie & Vérifications', badge: '96.4% Numérisé', value: '96.4%', caption: 'Notes numérisées', color: valid, icon: Icons.fact_check_outlined, lines: const ['INF301 (Algorithmique) : 96.4% saisi (81/84)', 'INF305 (Systèmes & Réseaux) : 78.0% saisi (66/84)', 'INF201 (C/C++ Fondamental) : 100% prêt (142/142)'], action: 'Accéder à la saisie et vérification', onPressed: () => _notice(context, 'La saisie et vérification des notes sera construite à l’étape suivante.'))),
                const SizedBox(width: 18),
                Expanded(child: _TeacherPillar(title: 'PILIER 3', heading: 'Requêtes & Réclamations', badge: '2 Urgentes', value: '04', caption: 'Reçues au total', color: red, icon: Icons.campaign_outlined, lines: const ['#REC-2024-0841 · Note TP omise (ABS)', '#REC-2024-0842 · Erreur note CC 06/20', '10 notes éliminatoires à surveiller'], action: 'Traiter toutes les requêtes (4)', onPressed: () => _notice(context, 'Le traitement des requêtes sera construit à l’étape suivante.'))),
              ]),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(flex: 2, child: _TeacherActivity()),
                const SizedBox(width: 18),
                const Expanded(child: _TeacherCompliance()),
              ]),
              const SizedBox(height: 26),
              const _TeacherFooter(),
            ]),
          ),
        ),
      );

  static void _notice(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _TeacherContext extends StatelessWidget {
  const _TeacherContext();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 16), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Faculté des Sciences  /  Dép. Mathématiques & Informatique', style: TextStyle(fontFamily: 'Fraunces', fontSize: 18, color: ink)), SizedBox(height: 6), Text('ANNÉE 2024–2025  ·  SEMESTRES IMPAIRS & PAIRS', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))])), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), color: const Color(0xFFE1EBDD), child: const Text('● HABILITATION PÉDAGOGIQUE VALIDÉE', style: TextStyle(fontFamily: 'monospace', color: valid, fontSize: 10))), const SizedBox(width: 20), const Text('Horodatage officiel : 24/02/2025 · 10:15 UTC+1', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))])));
}

class _TeacherHero extends StatelessWidget {
  const _TeacherHero();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('VUE CONSOLIDÉE   ·   Semestre 5 & Rapprochement Annuel', style: TextStyle(fontFamily: 'monospace', color: red, fontSize: 11)), SizedBox(height: 10), Text('Tableau de bord Enseignant — Synthèse Annuelle 2024–2025', style: TextStyle(fontFamily: 'Fraunces', fontSize: 27, fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 9), Text('Bienvenue, Pr. NDJOCK B. Cet espace donne un aperçu panoramique de vos 3 unités d’enseignement, de l’avancement de la saisie et du traitement prioritaire des recours et requêtes étudiantes avant transmission aux jurys de délibération.', style: TextStyle(color: slate, height: 1.4))])), const SizedBox(width: 20), Container(width: 255, padding: const EdgeInsets.all(16), color: paper, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('◷ Délai Légal de Clôture', style: TextStyle(fontFamily: 'monospace', color: red, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('28h 14m', style: TextStyle(fontFamily: 'Fraunces', fontSize: 24, color: red)), SizedBox(height: 5), Text('Forclusion stricte LMD (72h post-saisie)', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]))])));
}

class _TeacherPillar extends StatelessWidget {
  final String title, heading, badge, value, caption, action; final Color color; final IconData icon; final List<String> lines; final VoidCallback onPressed;
  const _TeacherPillar({required this.title, required this.heading, required this.badge, required this.value, required this.caption, required this.color, required this.icon, required this.lines, required this.action, required this.onPressed});
  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(side: BorderSide(color: color, width: 3)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color))),
              Chip(label: Text(badge, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: color)), backgroundColor: color.withOpacity(.1)),
            ]),
            const SizedBox(height: 12),
            Text(heading, style: const TextStyle(fontFamily: 'Fraunces', fontSize: 19, fontWeight: FontWeight.bold, color: ink)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontFamily: 'Fraunces', fontSize: 32, color: color)),
            Text(caption, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate)),
            const SizedBox(height: 14),
            ...lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Text(line, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)))),
            const Divider(),
            SizedBox(width: double.infinity, child: TextButton(onPressed: onPressed, child: Align(alignment: Alignment.centerLeft, child: Text('$action  →', style: TextStyle(color: color, fontWeight: FontWeight.bold))))),
          ]),
        ),
      );
}

class _TeacherActivity extends StatelessWidget {
  const _TeacherActivity();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('◴  Dernières Activités & Journal des Modifications', style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, color: ink)), Text('Piste d’Audit LMD Horodatée', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]), const Divider(), const _TeacherActivityLine(icon: Icons.verified_outlined, title: 'Procès-verbal de notes finalisé pour l’UE INF201', detail: '142 étudiants validés · Vérification et émargement de l’enseignant validés', time: 'Aujourd’hui 08:35'), const _TeacherActivityLine(icon: Icons.document_scanner_outlined, title: 'Appariement OCR des bordereaux d’examen INF301', detail: '81 copies physiques indexées sur 84 · 3 défaillances documentées', time: 'Aujourd’hui 07:48'), const _TeacherActivityLine(icon: Icons.mail_outline, title: 'Nouvelle requête déposée : #REC-2024-0842 (KAMGA Cédric)', detail: 'Motif de transcription CC · Pièce justificative jointe', time: 'Hier 18:22'), const SizedBox(height: 12), Text('● Intégrité de la chaîne de saisie garantie', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: valid))])));
}

class _TeacherActivityLine extends StatelessWidget {
  final IconData icon; final String title, detail, time;
  const _TeacherActivityLine({required this.icon, required this.title, required this.detail, required this.time});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [Icon(icon, color: gold, size: 19), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink, fontSize: 12)), const SizedBox(height: 3), Text(detail, style: const TextStyle(fontFamily: 'monospace', color: slate, fontSize: 10))])), Text(time, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: slate))]));
}

class _TeacherCompliance extends StatelessWidget {
  const _TeacherCompliance();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('REPÈRES DU SYSTÈME LMD', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), SizedBox(height: 10), Text('Règles de calcul', style: TextStyle(fontFamily: 'Fraunces', fontSize: 19, color: ink)), SizedBox(height: 8), Text('Aperçu de démonstration · Données du tableau de bord illustratives.', style: TextStyle(fontSize: 11, color: slate)), SizedBox(height: 12), Text('• Plan d’évaluation de chaque EC : poids total de 100 %', style: TextStyle(color: ink, fontSize: 11)), Text('• Arrondi supérieur de l’EC, puis de l’UE pondérée par les crédits', style: TextStyle(color: ink, fontSize: 11)), Text('• Admission annuelle : MGP ≥ 2/4 et chaque UE ≥ 35/100', style: TextStyle(color: ink, fontSize: 11)), Text('• EL : absence au rattrapage, admission annuelle impossible', style: TextStyle(color: red, fontSize: 11)), SizedBox(height: 15), Text('Consulter le Guide pédagogique pour le barème complet.', style: TextStyle(color: slate, fontSize: 11))])));
}

class _TeacherFooter extends StatelessWidget {
  const _TeacherFooter();
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), color: paperLight, child: const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('GNU — Gestion des Notes Universitaires', style: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.bold, color: ink)), Text('ANNÉE UNIVERSITAIRE 2024–2025   ·   ASSISTANCE & SUPPORT', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]));
}

class GradeEntryPage extends StatefulWidget {
  const GradeEntryPage({super.key});
  @override
  State<GradeEntryPage> createState() => _GradeEntryPageState();
}

class _GradeEntryPageState extends State<GradeEntryPage> {
  String selectedUe = 'INF301 : Algorithmique Avancée & Structures de Données';
  bool validated = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: GnuBrand(),
          actions: [
            TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.dashboard_outlined, size: 17), label: const Text('Tableau de bord')),
            TextButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La page Unités d’enseignement sera construite ensuite.'))), icon: const Icon(Icons.menu_book_outlined, size: 17), label: const Text('Unités d’enseignement')),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.fact_check_outlined, size: 17), label: const Text('Saisie et vérifications des notes')),
            TextButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La page Requêtes sera construite ensuite.'))), icon: const Icon(Icons.campaign_outlined, size: 17), label: const Text('Requêtes')),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _TeacherContext(),
                const SizedBox(height: 18),
                _GradeEntryIntro(selectedUe: selectedUe, onUe: (v) => setState(() => selectedUe = v)),
                const SizedBox(height: 16),
                const _GradeEntryActions(),
                const SizedBox(height: 16),
                _GradeEntrySummary(validated: validated, onValidate: () => setState(() => validated = true)),
                const SizedBox(height: 16),
                const _GradeEntryTabs(),
                const SizedBox(height: 16),
                const _GradeEntryTable(),
                const SizedBox(height: 16),
                _GradeEntryCommitment(validated: validated, onDraft: () => _notice(context, 'Brouillon enregistré.'), onSubmit: () => setState(() => validated = true)),
                const SizedBox(height: 24),
                const _TeacherFooter(),
              ]),
            ),
          ),
        ),
      );

  static void _notice(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _GradeEntryIntro extends StatelessWidget {
  final String selectedUe; final ValueChanged<String> onUe;
  const _GradeEntryIntro({required this.selectedUe, required this.onUe});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REGISTRE OFFICIEL   CODE ÉPREUVE · INF301-REG-2024S1', style: TextStyle(fontFamily: 'monospace', color: red, fontSize: 12)),
                SizedBox(height: 10),
                Text('Saisie & Contrôle Réglementaire des Notes', style: TextStyle(fontFamily: 'Fraunces', color: ink, fontSize: 28, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Bordereau officiel d’évaluation continue et terminale certifié par le responsable pédagogique de l’UE.', style: TextStyle(color: slate)),
              ])),
              const SizedBox(width: 20),
              SizedBox(width: 380, child: DropdownButtonFormField<String>(
                value: selectedUe,
                decoration: const InputDecoration(labelText: 'UNITÉ D’ENSEIGNEMENT (UE)', filled: true, fillColor: paper, border: InputBorder.none),
                items: const [
                  DropdownMenuItem(value: 'INF301 : Algorithmique Avancée & Structures de Données', child: Text('INF301 : Algorithmique Avancée & Structures de Données')),
                  DropdownMenuItem(value: 'INF305 : Systèmes & Réseaux', child: Text('INF305 : Systèmes & Réseaux')),
                  DropdownMenuItem(value: 'INF201 : C/C++ Fondamental', child: Text('INF201 : C/C++ Fondamental')),
                ],
                onChanged: (v) { if (v != null) onUe(v); },
              )),
            ]),
            const Divider(height: 28),
            const Row(children: [
              Expanded(child: _GradeWeight(title: 'Contrôle Continu (CC)', percent: '20%', text: 'Interrogations / Devoirs', color: red)),
              SizedBox(width: 12),
              Expanded(child: _GradeWeight(title: 'Travaux Pratiques (TP)', percent: '30%', text: 'Laboratoires & Mini-projets', color: gold)),
              SizedBox(width: 12),
              Expanded(child: _GradeWeight(title: 'Examen Terminal (SN)', percent: '50%', text: 'Session Normale d’amphithéâtre', color: ink)),
              SizedBox(width: 12),
              Expanded(child: _GradeWeight(title: 'Seuil éliminatoire', percent: '< 07.00/20', text: 'Toute note inférieure invalide l’UE.', color: red)),
            ]),
          ]),
        ),
      );
}

class _GradeWeight extends StatelessWidget {
  final String title, percent, text; final Color color;
  const _GradeWeight({required this.title, required this.percent, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), color: paper, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(percent, style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: ink)), const SizedBox(height: 4), Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]));
}

class _GradeEntryActions extends StatelessWidget {
  const _GradeEntryActions();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Wrap(spacing: 10, runSpacing: 8, children: [FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importation XLSX simulée.'))), icon: const Icon(Icons.upload_file_outlined), label: const Text('Importer une liste remplie (.xlsx)')), OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liste vierge des étudiants prête.'))), icon: const Icon(Icons.download_outlined), label: const Text('Télécharger la liste vierge (.xlsx)')), OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bordereau certifié prêt.'))), icon: const Icon(Icons.fact_check_outlined), label: const Text('Bordereau certifié (.xlsx)')), TextButton.icon(onPressed: () {}, icon: const Icon(Icons.print_outlined), label: const Text('Feuille d’émargement & notes'))])));
}

class _GradeEntrySummary extends StatelessWidget {
  final bool validated; final VoidCallback onValidate;
  const _GradeEntrySummary({required this.validated, required this.onValidate});
  @override
  Widget build(BuildContext context) => Card(shape: RoundedRectangleBorder(side: const BorderSide(color: gold, width: 2)), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Row(children: [CircleAvatar(radius: 20, backgroundColor: Color(0xFFE0EADF), child: Text('96%', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: valid))), SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Notes saisies : 81 / 84', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), Text('● Complétude globale : 96.4%', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: valid))])])), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('▣  3 notes manquantes', style: TextStyle(fontWeight: FontWeight.bold, color: red)), Text('1 absence justifiée (INC) · 2 non saisies', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate)), SizedBox(height: 8), Text('⚠ 2 notes sous le seuil < 07.00/20', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: red))])), FilledButton.icon(onPressed: onValidate, icon: Icon(validated ? Icons.verified : Icons.settings_outlined), label: Text(validated ? 'SAISIE VALIDÉE' : 'Vérifier & Valider la saisie'))])));
}

class _GradeEntryTabs extends StatelessWidget {
  const _GradeEntryTabs();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Wrap(spacing: 4, children: [FilledButton(onPressed: () {}, child: const Text('Vue Synthétique Globale (CC + TP + SN)')), TextButton(onPressed: () {}, child: const Text('Contrôle Continu (CC 20%)')), TextButton(onPressed: () {}, child: const Text('Travaux Pratiques (TP 30%)')), TextButton(onPressed: () {}, child: const Text('Session Normale (SN 50%)')), const SizedBox(width: 18), const Text('GROUPE : Tous (84)', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: slate))])));
}

class _GradeEntryTable extends StatelessWidget {
  const _GradeEntryTable();
  static DataCell cell(String text, {Color? color}) => DataCell(Text(text, style: TextStyle(fontFamily: 'monospace', color: color ?? ink)));
  @override
  Widget build(BuildContext context) => Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columnSpacing: 18, columns: const [DataColumn(label: Text('N°')), DataColumn(label: Text('MATRICULE')), DataColumn(label: Text('NOM & PRÉNOMS DE L’ÉTUDIANT')), DataColumn(label: Text('GRP')), DataColumn(label: Text('CC /20 (20%)')), DataColumn(label: Text('TP /20 (30%)')), DataColumn(label: Text('SN /20 (50%)')), DataColumn(label: Text('MOY. /20')), DataColumn(label: Text('DÉCISION LMD')), DataColumn(label: Text('VÉRIFICATION'))], rows: [
        DataRow(cells: [cell('01'), cell('21U2094'), const DataCell(Text('ABENA ESSOMBA Jean-Marc')), cell('G1'), cell('15.50'), cell('16.00'), cell('14.50'), cell('15.15'), const DataCell(Text('✓ VALIDÉ (B+)', style: TextStyle(color: valid))), const DataCell(Text('VÉRIFIÉ', style: TextStyle(color: valid)))]),
        DataRow(cells: [cell('02'), cell('21U2412'), const DataCell(Text('BIKOUÉ NDOUMBE Carine')), cell('G1'), cell('12.00'), cell('INC', color: pending), cell('--'), cell('— / —', color: pending), const DataCell(Text('INCOMPLET JUSTIFIÉ', style: TextStyle(color: pending))), const DataCell(Text('À RÉGULARISER', style: TextStyle(color: pending)))]),
        DataRow(cells: [cell('03'), cell('21U2991'), const DataCell(Text('EKANE TCHINDA Rostand')), cell('G2'), cell('06.50', color: red), cell('11.00'), cell('09.00'), cell('09.10', color: red), const DataCell(Text('ÉLIMINÉ (CC < 07)', style: TextStyle(color: red))), const DataCell(Text('ALERTE SEUIL', style: TextStyle(color: red)))]),
        DataRow(cells: [cell('04'), cell('21U3104'), const DataCell(Text('KAMDEM WABO Ulrich')), cell('G2'), cell('17.25'), cell('18.00'), cell('16.50'), cell('17.10'), const DataCell(Text('✓ VALIDÉ (A)', style: TextStyle(color: valid))), const DataCell(Text('VÉRIFIÉ', style: TextStyle(color: valid)))]),
        DataRow(cells: [cell('05'), cell('21U2849'), const DataCell(Text('DJOUKA FOTSO Franck Kevin')), cell('G1'), cell('14.00'), cell('13.50'), cell('11.50'), cell('12.60'), const DataCell(Text('✓ VALIDÉ (C+)', style: TextStyle(color: valid))), const DataCell(Text('VÉRIFIÉ', style: TextStyle(color: valid)))]),
        DataRow(cells: [cell('06'), cell('21U2118'), const DataCell(Text('MANGA ATANGANA Boris Cyrille')), cell('G2'), cell('11.50'), cell('10.00'), cell('— /20', color: red), cell('— / —', color: red), const DataCell(Text('NOTE SN MANQUANTE', style: TextStyle(color: red))), const DataCell(Text('À SAISIR', style: TextStyle(color: red)))]),
        DataRow(cells: [cell('07'), cell('21U2505'), const DataCell(Text('NGO MBOCK Madeleine Viviane')), cell('G1'), cell('10.50'), cell('12.00'), cell('10.00'), cell('10.70'), const DataCell(Text('✓ VALIDÉ (C)', style: TextStyle(color: valid))), const DataCell(Text('VÉRIFIÉ', style: TextStyle(color: valid)))]),
      ])));
}

class _GradeEntryCommitment extends StatelessWidget {
  final bool validated; final VoidCallback onDraft, onSubmit;
  const _GradeEntryCommitment({required this.validated, required this.onDraft, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Expanded(child: Row(children: [Icon(Icons.fact_check_outlined, color: ink, size: 28), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Engagement & Responsabilité Pédagogique', style: TextStyle(fontWeight: FontWeight.bold, color: ink)), SizedBox(height: 4), Text('En certifiant ce bordereau, le Pr. NDJOCK B. atteste de l’exactitude des notes saisies conformément à la charte universitaire LMD.', style: TextStyle(fontSize: 11, color: slate))]))])), OutlinedButton(onPressed: onDraft, child: const Text('Enregistrer brouillon')), const SizedBox(width: 10), FilledButton(onPressed: onSubmit, child: Text(validated ? 'Soumis au Décanat ✓' : 'Soumettre au Décanat'))])));
}

class CelluleDashboard extends StatelessWidget {
  const CelluleDashboard({super.key});
  @override
  Widget build(BuildContext context) => _PageShell(title: 'Classe : Licence 3 Informatique — Promotion A', subtitle: 'Cellule Informatique LMD · Structure & Hiérarchie · Session 2024–2025', children: [
        Row(children: [_Panel(title: 'Effectif inscrit', value: '84', caption: 'étudiants · 100% immatriculés', icon: Icons.groups_outlined, color: ink), _Panel(title: 'Crédits ECTS (S5)', value: '30', caption: '6 unités d’enseignement', icon: Icons.school_outlined, color: gold), _Panel(title: 'Quota enseignant', value: '08', caption: 'enseignants affectés', icon: Icons.badge_outlined, color: valid)]),
        const SizedBox(height: 18),
        _Section(title: 'Référentiel des strates · Organigramme officiel', child: const Column(children: [ListTile(leading: Icon(Icons.account_balance_outlined), title: Text('Université de Douala'), trailing: Text('6 FAC')), ListTile(leading: Icon(Icons.account_tree_outlined), title: Text('Faculté des Sciences · Département Informatique'), trailing: Text('4 DÉP')), ListTile(leading: Icon(Icons.layers_outlined, color: red), title: Text('L3 Info — Promo A'), trailing: Text('84 ÉTUD.')), Divider(), ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Programme & Unités d’Enseignement'), subtitle: Text('6 UEs · 30 crédits · 5/6 validées'))])),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.publish), label: const Text('Publier les résultats')),
      ]);
}

class _PageShell extends StatelessWidget {
  final String title, subtitle; final List<Widget> children;
  const _PageShell({required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: paperLight,
                    border: Border.all(color: ink.withOpacity(.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SESSION ACADÉMIQUE EN COURS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: valid)),
                      const SizedBox(height: 8),
                      Text(title, style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text(subtitle, style: const TextStyle(color: slate)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Metric extends StatelessWidget { final String label, value, suffix; final Color color; const _Metric({required this.label, required this.value, required this.suffix, required this.color}); @override Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 12), Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 28, color: color)), Text(suffix, style: const TextStyle(color: slate))])))); }
class _Panel extends StatelessWidget { final String title, value, caption; final IconData icon; final Color color; const _Panel({required this.title, required this.value, required this.caption, required this.icon, required this.color}); @override Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12), Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 30, color: color)), Text(caption, style: const TextStyle(color: slate))])))); }
class _Section extends StatelessWidget { final String title; final Widget child; const _Section({required this.title, required this.child}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const Divider(), child]))); }
class _Alert extends StatelessWidget { final String title, text, action; final Color color; const _Alert({required this.title, required this.text, required this.color, required this.action}); @override Widget build(BuildContext context) => Card(color: paperLight, child: ListTile(leading: Icon(Icons.notification_important_outlined, color: color), title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), subtitle: Text('$text\n$action →'))); }
class _GradesTable extends StatelessWidget {
  const _GradesTable();

  @override
  Widget build(BuildContext context) => DataTable(
        columns: const [
          DataColumn(label: Text('CODE UE')),
          DataColumn(label: Text('INTITULÉ')),
          DataColumn(label: Text('CRÉDITS')),
          DataColumn(label: Text('CC /20')),
          DataColumn(label: Text('TP /20')),
          DataColumn(label: Text('STATUT')),
        ],
        rows: const [
          DataRow(cells: [DataCell(Text('INF301')), DataCell(Text('Conception orientée objet')), DataCell(Text('5 ECTS')), DataCell(Text('14.50')), DataCell(Text('10.00')), DataCell(Text('Arbitrage'))]),
          DataRow(cells: [DataCell(Text('INF303')), DataCell(Text('Systèmes de gestion BD')), DataCell(Text('5 ECTS')), DataCell(Text('15.00')), DataCell(Text('16.50')), DataCell(Text('En bonne voie'))]),
          DataRow(cells: [DataCell(Text('INF307')), DataCell(Text('Algorithmique avancée')), DataCell(Text('5 ECTS')), DataCell(Text('8.50')), DataCell(Text('—')), DataCell(Text('À surveiller'))]),
        ],
      );
}
class _Feature extends StatelessWidget { final IconData icon; final String title, text; const _Feature({required this.icon, required this.title, required this.text}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: ListTile(tileColor: Colors.white10, leading: Icon(icon, color: gold), title: Text(title, style: const TextStyle(color: paperLight, fontFamily: 'Fraunces')), subtitle: Text(text, style: const TextStyle(color: paper)))); }
class GnuBrand extends StatelessWidget { GnuBrand({super.key}); @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Image.asset('assets/logo_gnu.png', width: 32, height: 32), const SizedBox(width: 8), const Text('GNU', style: TextStyle(fontFamily: 'Fraunces', fontSize: 23, color: ink)), const SizedBox(width: 10), const Text('SYSTÈME ACADÉMIQUE LMD · PORTAIL DE CONNEXION', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: slate))]); }
