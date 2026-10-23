import 'package:flutter_test/flutter_test.dart';
import 'package:gnu_frontend/domain.dart';

void main() {
  test('notes : virgule acceptée, limites et absences contrôlées', () {
    expect(DemoStore.parseMark('12,5'), 12.5);
    expect(DemoStore.parseMark('0'), 0);
    expect(DemoStore.parseMark('20'), 20);
    for (final raw in ['', 'ABS', '-1', '21', 'NaN', '1e1', '12.999']) {
      expect(DemoStore.parseMark(raw), isNull, reason: raw);
    }
  });
  test('publication bloquée puis snapshot stable après correction', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    expect(store.publish(), isFalse);
    expect(store.validateGrades(), isFalse);
    store.changeMark(3, false, '14');
    expect(store.submitGrades(), isFalse);
    expect(store.validateGrades(), isTrue);
    expect(store.submitGrades(), isTrue);
    expect(store.publish(), isTrue);
    final snapshot = store.publishedScores.first;
    store.changeMark(0, true, '10');
    expect(store.gradesValidated, isFalse);
    expect(store.gradesSubmitted, isFalse);
    expect(store.publishedScores.first, snapshot);
    expect(store.publish(), isFalse);
    store.validateGrades();
    store.submitGrades();
    store.publish();
    expect(store.publicationVersion, 2);
    expect(store.publishedScores.first, isNot(snapshot));
  });
  test('changement de pondération exige une nouvelle validation', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    store.changeMark(3, false, '14');
    store.validateGrades();
    store.submitGrades();
    store.changeWeights(40);
    expect(store.examWeight, 60);
    expect(store.gradesValidated, isFalse);
    expect(store.gradesSubmitted, isFalse);
    expect(() => store.changeWeights(101), throwsArgumentError);
  });
  test('choix semestriels verrouillés après soumission', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    final selectedUnit = store.courses.last;
    store.selectCourse(selectedUnit, true);
    expect(store.selectedCourses, contains('PPE212'));
    expect(store.selectedCredits, 3);
    expect(store.submitEnrollment('Semestre 2'), isTrue);
    store.selectCourse(store.courses.last, false);
    expect(store.selectedCredits, 3);
    store.approveEnrollment('Semestre 2');
    expect(store.enrollmentApproved, isTrue);
  });
  test('compte en doublon refusé et décision possible sans motif', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    expect(
      () => store.addAccount(
        DemoAccount('Autre', 'ALEX@example.test', UserRole.student),
      ),
      throwsArgumentError,
    );
    store.decide(store.requests.first, true, '');
    expect(store.requests.first.status, 'Acceptée');
    expect(store.openRequests, 0);
  });
}
