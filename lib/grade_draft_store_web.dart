import 'package:web/web.dart' as web;

import 'grade_draft_store.dart';

GradeDraftStore createGradeDraftStore() => _BrowserGradeDraftStore();

class _BrowserGradeDraftStore implements GradeDraftStore {
  // This namespace is reserved for demo data, never authenticated records.
  static const _key = 'gnu.grade-entry.demo.v1';

  @override
  String get locationLabel => 'ce navigateur';

  @override
  Future<String?> read() async => web.window.localStorage.getItem(_key);

  @override
  Future<void> write(String value) async {
    // Storage errors must reach the UI so an unsuccessful save is not reported
    // as successful (for example, when local storage is disabled or full).
    web.window.localStorage.setItem(_key, value);
  }
}
