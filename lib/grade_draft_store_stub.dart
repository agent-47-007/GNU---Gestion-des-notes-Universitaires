import 'grade_draft_store.dart';

final GradeDraftStore _sessionStore = _SessionGradeDraftStore();

GradeDraftStore createGradeDraftStore() => _sessionStore;

class _SessionGradeDraftStore implements GradeDraftStore {
  String? _value;

  @override
  String get locationLabel => 'cette session';

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async {
    _value = value;
  }
}
