import 'package:flutter/material.dart';

const navy = Color(0xFF142E3A);
const emerald = Color(0xFF087F6A);
const canvas = Color(0xFFF4F7F8);
const muted = Color(0xFF687C86);
const stroke = Color(0xFFE1E9EB);

ThemeData buildTheme({bool dark = false}) => ThemeData(
  useMaterial3: true,
  brightness: dark ? Brightness.dark : Brightness.light,
  scaffoldBackgroundColor: dark ? const Color(0xFF101C24) : canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: emerald,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: emerald,
    secondary: navy,
    surface: dark ? const Color(0xFF172A33) : Colors.white,
    error: const Color(0xFFB33B43),
  ),
  fontFamily: 'Arial',
  textTheme: TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: dark ? Colors.white : navy,
      letterSpacing: -1.1,
    ),
    headlineMedium: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w700,
      color: dark ? Colors.white : navy,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: dark ? Colors.white : navy,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: navy,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: navy, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: dark ? const Color(0xFF203640) : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: stroke),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: stroke),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      side: const BorderSide(color: stroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: stroke, thickness: 1),
);

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: emerald,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school_outlined, color: Colors.white, size: 25),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GNU',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: dark ? Colors.white : navy,
              letterSpacing: 2,
            ),
          ),
          Text(
            'CAMPUS NUMÉRIQUE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.8,
              color: dark ? Colors.white60 : muted,
            ),
          ),
        ],
      ),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: stroke),
      borderRadius: BorderRadius.circular(16),
    ),
    // ListTile paints selection/ink on its nearest Material. Keeping a local
    // transparent Material prevents decorated panels from hiding those effects
    // (and avoids Flutter's ListTile background assertion in tests).
    child: Material(color: Colors.transparent, child: child),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color = emerald});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: muted, height: 1.5)),
          ],
        );
        return constraints.maxWidth < 650
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  if (action != null) ...[const SizedBox(width: 16), action!],
                ],
              );
      },
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF5E4) : const Color(0xFFEAF5F1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning ? Icons.info_outline : Icons.verified_user_outlined,
          size: 20,
          color: warning ? const Color(0xFF986119) : emerald,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: warning ? const Color(0xFF825719) : emerald,
            ),
          ),
        ),
      ],
    ),
  );
}

class MetricGrid extends StatelessWidget {
  const MetricGrid(this.items, {super.key});
  final List<(String, String, String, IconData)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 950
          ? 4
          : constraints.maxWidth > 480
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items
            .map(
              (item) => SizedBox(
                width: width,
                child: Panel(
                  padding: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.$1,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ),
                          Icon(item.$4, size: 19, color: emerald),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          color: navy,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.$3,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({super.key, required this.main, required this.aside});
  final Widget main, aside;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 850
        ? Column(children: [main, const SizedBox(height: 20), aside])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: aside),
            ],
          ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(26),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 38, color: muted),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

void toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
    .showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 400, child: Text(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ??
    false;
