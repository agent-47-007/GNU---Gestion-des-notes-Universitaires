import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'ui.dart';

class PublicDirectoryPage extends StatefulWidget {
  const PublicDirectoryPage({
    super.key,
    required this.api,
    required this.onSignIn,
  });

  final StudentApiClient api;
  final VoidCallback onSignIn;

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
                    if (institution['site_web'] != null) ...[
                      const Text(
                        'Site institutionnel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText('${institution['site_web']}'),
                      const SizedBox(height: 12),
                    ],
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
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                          FilledButton.icon(
                            onPressed: widget.onSignIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Espace académique'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'DÉCOUVRIR · COMPARER · S’ORIENTER',
                        style: TextStyle(
                          color: Color(0xFF8CDEC5),
                          letterSpacing: 1.5,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 28),
                      TextField(
                        controller: search,
                        decoration: const InputDecoration(
                          labelText: 'Rechercher un établissement ou une ville',
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
                                                label: const Text(
                                                  'Voir la fiche',
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
