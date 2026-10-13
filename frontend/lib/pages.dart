import 'package:flutter/material.dart';

import 'domain.dart';
import 'ui.dart';
export 'features.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.role,
    required this.store,
    required this.navigate,
  });
  final UserRole role;
  final DemoStore store;
  final ValueChanged<String> navigate;

  @override
  Widget build(BuildContext context) {
    final student = role == UserRole.student;
    final teacher = role == UserRole.teacher;
    final title = student
        ? 'Votre parcours, en un regard.'
        : teacher
        ? 'L’essentiel de vos enseignements.'
        : 'Votre campus, sous contrôle.';
    final metrics = student
        ? <(String, String, String, IconData)>[
            (
              'Crédits acquis',
              '25 / 30',
              'Résultats fictifs du semestre 1',
              Icons.school_outlined,
            ),
            (
              'Unités d’enseignement',
              '6',
              'Licence 2 · Informatique',
              Icons.menu_book_outlined,
            ),
            (
              'UE à reprendre',
              '1',
              'Mathématiques discrètes',
              Icons.event_repeat,
            ),
            (
              'Requêtes en cours',
              '${store.openRequests}',
              'Suivi de vos demandes',
              Icons.chat_bubble_outline,
            ),
          ]
        : teacher
        ? <(String, String, String, IconData)>[
            (
              'Enseignement affecté',
              '1',
              'INF 201 · Algorithmique',
              Icons.menu_book_outlined,
            ),
            (
              'Étudiants inscrits',
              '${store.marks.length}',
              'Groupe de démonstration',
              Icons.people_outline,
            ),
            (
              'Notes à compléter',
              '${store.missingMarks}',
              'Sur ${store.marks.length * 2} notes attendues',
              Icons.edit_note,
            ),
            (
              'Requêtes à examiner',
              '${store.openRequests}',
              'Demandes étudiantes',
              Icons.chat_bubble_outline,
            ),
          ]
        : <(String, String, String, IconData)>[
            (
              'Comptes actifs',
              '${store.accounts.where((a) => a.active).length}',
              '${store.accounts.length} comptes dans la démo',
              Icons.people_outline,
            ),
            (
              'Programmes',
              '${store.programs.length}',
              'Structure pédagogique',
              Icons.account_tree_outlined,
            ),
            (
              'Registre transmis',
              store.gradesSubmitted ? '1 / 1' : '0 / 1',
              'À contrôler avant publication',
              Icons.fact_check_outlined,
            ),
            (
              'Publications',
              '${store.publicationVersion}',
              'Versions de démonstration',
              Icons.publish_outlined,
            ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Bonjour, ${student
              ? 'Alex'
              : teacher
              ? 'Dr. Nkom'
              : 'Camille'} 👋',
          title,
          action: const StatusBadge('Licence 2 · Informatique', color: muted),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [navy, Color(0xFF18564E)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student
                            ? 'VOTRE PROCHAINE ÉTAPE'
                            : teacher
                            ? 'À FINALISER'
                            : 'PILOTAGE ACADÉMIQUE',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.8,
                          color: Color(0xFF8CDBC6),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        student
                            ? (store.enrollmentSubmitted
                                  ? 'Vos choix pédagogiques sont transmis.'
                                  : 'Préparez votre nouveau semestre.')
                            : teacher
                            ? (store.gradesSubmitted
                                  ? 'Votre registre a été transmis.'
                                  : 'Chaque note compte.')
                            : 'Une publication fiable commence ici.',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        student
                            ? 'Retrouvez vos UE et suivez votre inscription pédagogique.'
                            : teacher
                            ? 'Complétez le registre, vérifiez les résultats et transmettez vos notes.'
                            : 'Vérifiez les registres transmis avant de rendre les résultats visibles.',
                        style: const TextStyle(
                          color: Color(0xFFB9D2D0),
                          height: 1.6,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: navy,
                        ),
                        onPressed: () => navigate(
                          student
                              ? 'enrollment'
                              : teacher
                              ? 'grades'
                              : 'publications',
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 17),
                        label: Text(
                          student
                              ? 'Mon inscription'
                              : teacher
                              ? 'Ouvrir le registre'
                              : 'Contrôler les validations',
                        ),
                      ),
                    ],
                  ),
                ),
                if (box.maxWidth > 680) ...[
                  const SizedBox(width: 32),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .07),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Icon(
                      student
                          ? Icons.school_outlined
                          : teacher
                          ? Icons.edit_note
                          : Icons.verified_outlined,
                      size: 54,
                      color: const Color(0xFF8CDBC6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        MetricGrid(metrics),
        const SizedBox(height: 28),
        ResponsiveSplit(
          main: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  student
                      ? 'Mes enseignements'
                      : teacher
                      ? 'Mon registre de notes'
                      : 'État des opérations',
                  subtitle: student
                      ? 'Semestre 1 · Résultats publiés de démonstration'
                      : 'Un suivi concret de vos actions',
                ),
                if (student)
                  ...store.courses
                      .take(4)
                      .map(
                        (course) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: canvas,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  size: 18,
                                  color: emerald,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${course.code} · ${course.credits} crédits',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(
                                '${course.score!.toInt()} / 100',
                                color: course.score! < 50
                                    ? const Color(0xFFA26917)
                                    : emerald,
                              ),
                            ],
                          ),
                        ),
                      )
                else ...[
                  _step(
                    '01',
                    'Compléter les notes',
                    '${store.missingMarks} note(s) manquante(s) ou à régulariser',
                    store.missingMarks == 0,
                  ),
                  _step(
                    '02',
                    'Valider et transmettre',
                    'Contrôle du registre par l’enseignant',
                    store.gradesSubmitted,
                  ),
                  _step(
                    '03',
                    'Publier les résultats',
                    'Version consultable dans l’espace étudiant',
                    store.publicationVersion > 0,
                  ),
                ],
                const Divider(),
                TextButton.icon(
                  onPressed: () => navigate(
                    student
                        ? 'results'
                        : teacher
                        ? 'grades'
                        : 'publications',
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    student
                        ? 'Voir tous mes résultats'
                        : 'Poursuivre le parcours',
                  ),
                ),
              ],
            ),
          ),
          aside: Column(
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Accès rapides'),
                    ...destinationsForDashboard(role).map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item.$3, color: emerald, size: 21),
                        title: Text(
                          item.$1,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(
                          Icons.arrow_outward,
                          size: 16,
                          color: muted,
                        ),
                        onTap: () => navigate(item.$2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Activité récente',
                      subtitle: 'Cette session de démonstration',
                    ),
                    ...store.activity
                        .take(3)
                        .map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: emerald,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    event,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _step(String number, String title, String detail, bool complete) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: complete ? const Color(0xFFE9F4F0) : canvas,
              child: complete
                  ? const Icon(Icons.check, size: 18, color: emerald)
                  : Text(
                      number,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

List<(String, String, IconData)> destinationsForDashboard(UserRole role) =>
    switch (role) {
      UserRole.student => [
        ('Consulter mon bulletin', 'results', Icons.description_outlined),
        ('Suivre mes requêtes', 'requests', Icons.chat_bubble_outline),
      ],
      UserRole.teacher => [
        ('Configurer une évaluation', 'evaluations', Icons.tune),
        ('Examiner les requêtes', 'requests', Icons.chat_bubble_outline),
        ('Voir les rattrapages', 'retakes', Icons.event_repeat),
      ],
      UserRole.agent => [
        ('Gérer les comptes', 'accounts', Icons.people_outline),
        ('Vérifier les inscriptions', 'enrollment', Icons.playlist_add_check),
        ('Organiser les programmes', 'academic', Icons.account_tree_outlined),
      ],
    };
