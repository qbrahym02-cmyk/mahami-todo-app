import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/services/update_service.dart';

void main() {
  test('compareVersions', () {
    expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0.0', '2.0.0'), 0);
    expect(compareVersions('1.0.0+5', '1.0.0'), 0);
    expect(compareVersions('1.0', '1.0.0'), 0);
  });
}
