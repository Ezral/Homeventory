import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/core/layout/web_layout.dart';

void main() {
  test('a single match stays one column wide', () {
    expect(searchResultColumnCount(availableWidth: 1400, resultCount: 1), 1);
  });

  test('multiple matches use four columns on a wide row', () {
    expect(searchResultColumnCount(availableWidth: 1200, resultCount: 9), 4);
  });

  test('two matches stay two columns even on a wide row', () {
    expect(searchResultColumnCount(availableWidth: 1200, resultCount: 2), 2);
  });

  test('a narrow phone stays one column', () {
    expect(searchResultColumnCount(availableWidth: 360, resultCount: 8), 1);
  });

  test('medium width grows to two or three columns', () {
    expect(searchResultColumnCount(availableWidth: 500, resultCount: 8), 2);
    expect(searchResultColumnCount(availableWidth: 750, resultCount: 8), 3);
  });
}
