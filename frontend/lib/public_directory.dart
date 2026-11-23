import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_portal_navigation.dart';

import 'api_client.dart';
import 'ui.dart';

class PublicDirectoryPage extends StatefulWidget {
  const PublicDirectoryPage({
    super.key,
    required this.api,
    required this.onSignIn,
    this.onInstitutionSignIn,
    this.onTeacherSignIn,
  });

  final StudentApiClient api;
  final VoidCallback onSignIn;
  final VoidCallback? onTeacherSignIn;
  final void Function(int universityId, String name)? onInstitutionSignIn;

  @override
  State<PublicDirectoryPage> createState() => _PublicDirectoryPageState();
}

class _PublicDirectoryPageState extends State<PublicDirectoryPage> {
  final search = TextEditingController();
  Timer? debounce;
  late Future<Map<String, dynamic>> result;
  String? region;
  String? category;
  int page = 1;

  static const categories = {
    'UNIVERSITE_PUBLIQUE': 'Universités publiques',
    'INSTITUTION_PRIVEE': 'Universités et institutions privées',
    'IPES': 'Institutions privées (IPES)',
    'INTERNATIONAL': 'Institutions internationales',
  };

  @override
  void initState() {
    super.initState();
    result = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() => widget.api.publicInstitutions(
    query: search.text.trim(),
    region: region,
    category: category,
    page: page,
  );

  void reload({bool resetPage = true}) {
    if (resetPage) page = 1;
    setState(() {
      result = _fetch();
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    _scroll.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget sourceNotes(Map entity, {bool schoolOffers = false}) {
    final sources = (entity['sources'] as List? ?? []).whereType<Map>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final source in sources) ...[
          const SizedBox(height: 8),
          if (source['details'] is Map) ...[
            if (source['details']['duree'] != null)
              Text('Durée publiée : ${source['details']['duree']}'),
            if (source['details']['methode_niveaux'] != null)
              Text(
                '${source['details']['methode_niveaux']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (schoolOffers &&
                (source['details']['formations'] as List? ?? []).isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Formations publiées par l’établissement'),
                subtitle: const Text(
                  'Département de rattachement non précisé par la source',
                ),
                children: [
                  for (final offer
                      in (source['details']['formations'] as List)
                          .whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${offer['nom']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (offer['cycle'] != null) '${offer['cycle']}',
                              if (offer['duree'] != null) '${offer['duree']}',
                              if ((offer['niveaux'] as List? ?? []).isNotEmpty)
                                (offer['niveaux'] as List).join(' · '),
                            ].join(' · '),
                          ),
                          if (offer['source_url'] != null)
                            SelectableText(
                              '${offer['source_url']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
          Text(
            source['annee_source'] == '2026-2027'
                ? 'Source pour l’année 2026–2027'
                : 'Ouverture 2026–2027 à confirmer auprès de l’établissement',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SelectableText(
            '${source['source_url']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Consultation : ${source['consulte_le']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (source['source_date'] != null)
            Text(
              'Document du ${source['source_date']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }

  Uri? officialSite(Map row) {
    final raw = row['site_web'];
    final uri = raw is String ? Uri.tryParse(raw) : null;
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Future<void> visitSite(Uri site) async {
    if (openInstitutionSite(site.toString())) return;
    await Clipboard.setData(ClipboardData(text: site.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse du site officiel copiée.')),
      );
    }
  }

  Future<void> details(Map<String, dynamic> row) async {
    final data = widget.api.publicInstitution((row['id'] as num).toInt());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row['nom']}'),
        content: SizedBox(
          width: 760,
          child: FutureBuilder<Map<String, dynamic>>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text(
                  'La fiche ne peut pas être chargée. Réessayez.',
                );
              if (!snapshot.hasData)
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              final detail = snapshot.data!;
              final institution = detail['institution'] as Map;
              final schools = (detail['etablissements'] as List? ?? [])
                  .whereType<Map>()
                  .toList();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categories['${institution['categorie']}'] ??
                          '${institution['categorie']}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        institution['region'],
                        institution['ville'],
                      ].where((v) => v != null).join(' · '),
                    ),
                    const SizedBox(height: 16),
                    if (officialSite(institution) case final site?) ...[
                      const Text(
                        'Site institutionnel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => visitSite(site),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Ouvrir le site officiel'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (officialSite(institution) == null)
                      const Text(
                        'Vitrine GNU · Aucun site officiel renseigné.',
                      ),
                    const Text(
                      'Source de la fiche',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText('${institution['source_url']}'),
                    Text('Consultée le ${institution['consulte_le']}'),
                    Text(
                      institution['source_date'] == null
                          ? 'Date de publication non précisée : actualité à confirmer.'
                          : 'Publication du ${institution['source_date']}',
                    ),
                    if (institution['verification'] ==
                        'MENTION_SOURCE_A_ACTUALISER')
                      const Text(
                        'Mention historique : présence actuelle à vérifier.',
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'Facultés, écoles et formations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (schools.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'La structure détaillée de cet établissement n’est pas encore renseignée. Consultez sa source officielle.',
                        ),
                      ),
                    for (final school in schools)
                      ExpansionTile(
                        title: Text('${school['nom_fac']}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: sourceNotes(school, schoolOffers: true),
                          ),
                          for (final department
                              in (school['departements'] as List)
                                  .whereType<Map>())
                            ExpansionTile(
                              title: Text('${department['nom_depart']}'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: sourceNotes(department),
                                ),
                                if ((department['filieres'] as List).isEmpty)
                                  const ListTile(
                                    title: Text('Filières à compléter'),
                                  ),
                                for (final program
                                    in (department['filieres'] as List)
                                        .whereType<Map>())
                                  ListTile(
                                    title: Text('${program['nom_f']}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (program['niveaux'] as List).isEmpty
                                              ? 'Niveaux à confirmer'
                                              : (program['niveaux'] as List)
                                                    .whereType<Map>()
                                                    .map(
                                                      (n) =>
                                                          '${n['libelle_niv']}',
                                                    )
                                                    .join(' · '),
                                        ),
                                        sourceNotes(program),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${detail['information']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          if (row['universite_id'] case final num universityId)
            if (widget.onInstitutionSignIn != null)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onInstitutionSignIn!(
                    universityId.toInt(),
                    '${row['nom']}',
                  );
                },
                child: const Text('Portail de cet établissement'),
              ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  final _scroll = ScrollController();
  final _searchKey = GlobalKey();
  final _searchFocus = FocusNode();
  static const _contactEmail = 'fitzgerald.ngue@facsciences-uy1.cm';
  static const _contactPhones = ['+237 651 542 214', '+237 593 338 107'];

  void _focusDirectory() {
    final field = _searchKey.currentContext;
    if (field != null) {
      Scrollable.ensureVisible(
        field,
        duration: const Duration(milliseconds: 250),
      );
      _searchFocus.requestFocus();
    }
  }

  void _showInformation(String section) {
    final isContact = section == 'Contact';
    final isHelp = section == 'Aide';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(section),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHelp) ...[
                  const Text(
                    'Accéder au portail enseignant',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Connectez-vous avec votre identifiant GNU. Si vous n’avez pas de compte, ouvrez une demande et sélectionnez votre établissement.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Consulter une formation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Recherchez l’établissement par son nom ou sa ville, puis ouvrez sa fiche publique.',
                  ),
                ] else ...[
                  if (!isContact) ...[
                    const Text(
                      'GNU — Gestion des notes universitaires',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GNU rassemble un annuaire des établissements camerounais et un portail de gestion académique. Les enseignants saisissent les notes de leurs enseignements. Les agents habilités vérifient les résultats et préparent leur transmission à la cellule informatique.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Fitzgerald Ngue · Contact du projet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(_contactEmail),
                  const SizedBox(height: 12),
                  for (final phone in _contactPhones) SelectableText(phone),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: _contactEmail),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Adresse courriel copiée.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier le courriel'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (isHelp)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                (widget.onTeacherSignIn ?? widget.onSignIn)();
              },
              child: const Text('Connexion enseignant'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F7F6),
    body: SafeArea(
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF102B36), Color(0xFF125C51)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          const Brand(dark: true),
                          for (final section in [
                            'Accueil',
                            'Annuaire',
                            'Aide',
                            'À propos',
                            'Contact',
                          ])
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: switch (section) {
                                'Accueil' => () {
                                  _searchFocus.unfocus();
                                  _scroll.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  );
                                },
                                'Annuaire' => _focusDirectory,
                                _ => () => _showInformation(section),
                              },
                              child: Text(section),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Universités et établissements du Cameroun',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Un annuaire public pour explorer les établissements et leurs formations.\nConsultation libre, sans création de compte.',
                        style: TextStyle(
                          color: Color(0xFFD6E9E4),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                widget.onTeacherSignIn ?? widget.onSignIn,
                            icon: const Icon(Icons.cast_for_education_outlined),
                            label: const Text('Connexion enseignant'),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: widget.onSignIn,
                            child: const Text('Espace académique'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: _searchKey,
                        focusNode: _searchFocus,
                        controller: search,
                        decoration: const InputDecoration(
                          hintText: 'Nom de l’établissement ou ville',
                          labelText: 'Rechercher',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          prefixIcon: Icon(Icons.search),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        onChanged: (_) {
                          debounce?.cancel();
                          debounce = Timer(
                            const Duration(milliseconds: 350),
                            () => reload(),
                          );
                        },
                        onSubmitted: (_) {
                          debounce?.cancel();
                          reload();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1228),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: result,
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_off_outlined, size: 36),
                                const SizedBox(height: 12),
                                const Text(
                                  'L’annuaire est temporairement indisponible.',
                                ),
                                const Text(
                                  'Vous pouvez toujours accéder à votre espace académique.',
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: reload,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        );
                      if (!snapshot.hasData)
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      final data = snapshot.data!;
                      final rows = (data['data'] as List? ?? [])
                          .whereType<Map>()
                          .toList();
                      final regions = (data['regions'] as List? ?? [])
                          .map((v) => '$v')
                          .toList();
                      final pagination = data['pagination'] as Map? ?? {};
                      final stats = (data['statistiques'] as List? ?? [])
                          .whereType<Map>();
                      final source = data['sources'] as Map?;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final stat in stats)
                                Chip(
                                  avatar: const Icon(
                                    Icons.account_balance_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '${stat['nombre']} ${categories['${stat['categorie']}'] ?? stat['categorie']}',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LayoutBuilder(
                            builder: (context, box) => Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: box.maxWidth < 620
                                      ? box.maxWidth
                                      : 300,
                                  child: DropdownButtonFormField<String>(
                                    key: const ValueKey('directory-category'),
                                    initialValue: category,
                                    decoration: const InputDecoration(
                                      labelText: 'Type d’établissement',
                                    ),
                                    isExpanded: true,
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Tous les établissements'),
                                      ),
                                      for (final entry in categories.entries)
                                        DropdownMenuItem(
                                          value: entry.key,
                                          child: Text(
                                            entry.value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      category = v == '' ? null : v;
                                      reload();
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: box.maxWidth < 620
                                      ? box.maxWidth
                                      : 280,
                                  child: DropdownButtonFormField<String>(
                                    key: const ValueKey('directory-region'),
                                    isExpanded: true,
                                    initialValue: region,
                                    decoration: const InputDecoration(
                                      labelText: 'Région',
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Toutes les régions'),
                                      ),
                                      for (final r in regions)
                                        DropdownMenuItem(
                                          value: r,
                                          child: Text(r),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      region = v == '' ? null : v;
                                      reload();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${pagination['total'] ?? 0} résultats',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                'Aucun établissement ne correspond à votre recherche.',
                              ),
                            ),
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns = box.maxWidth >= 1000
                                  ? 3
                                  : box.maxWidth >= 650
                                  ? 2
                                  : 1;
                              final width =
                                  (box.maxWidth - (columns - 1) * 16) / columns;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  for (final row in rows)
                                    SizedBox(
                                      width: width,
                                      child: Card(
                                        margin: EdgeInsets.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.account_balance,
                                                    color: emerald,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      categories['${row['categorie']}'] ??
                                                          '${row['categorie']}',
                                                      style: const TextStyle(
                                                        color: muted,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                '${row['nom']}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                [row['region'], row['ville']]
                                                    .where((v) => v != null)
                                                    .join(' · '),
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Fiche sourcée · formations selon disponibilité',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: muted,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              if (officialSite(row)
                                                  case final site?)
                                                FilledButton.icon(
                                                  onPressed: () =>
                                                      visitSite(site),
                                                  icon: const Icon(
                                                    Icons.open_in_new,
                                                  ),
                                                  label: const Text(
                                                    'Site officiel',
                                                  ),
                                                ),
                                              OutlinedButton.icon(
                                                onPressed: () => details(
                                                  Map<String, dynamic>.from(
                                                    row,
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.arrow_forward,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  officialSite(row) == null
                                                      ? 'Voir la vitrine'
                                                      : 'Voir la fiche',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: page > 1
                                    ? () {
                                        page--;
                                        reload(resetPage: false);
                                      }
                                    : null,
                                child: const Text('Précédent'),
                              ),
                              Text(
                                'Page ${pagination['page'] ?? 1} / ${pagination['pages'] ?? 1}',
                              ),
                              OutlinedButton(
                                onPressed:
                                    page <
                                        ((pagination['pages'] as num?)
                                                ?.toInt() ??
                                            1)
                                    ? () {
                                        page++;
                                        reload(resetPage: false);
                                      }
                                    : null,
                                child: const Text('Suivant'),
                              ),
                            ],
                          ),
                          if (source != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sources MINESUP · consultation du ${source['consulte_le']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final reference
                                      in (source['sources'] as List? ?? [])
                                          .whereType<Map>())
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: SelectableText(
                                        '${reference['date'] ?? 'Publication non datée'} · ${reference['url']}',
                                      ),
                                    ),
                                  Text(
                                    '${source['limite']}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
