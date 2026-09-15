import 'grade_draft_store_stub.dart'
    if (dart.library.js_interop) 'grade_draft_store_web.dart' as platform;

/// Local storage for the demo grade register; no server synchronization.
abstract class GradeDraftStore {
  Future<String?> read();

  Future<void> write(String value);

  String get locationLabel;
}

GradeDraftStore createGradeDraftStore() => platform.createGradeDraftStore();
