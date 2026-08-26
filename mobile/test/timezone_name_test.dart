import 'package:flutter_test/flutter_test.dart';
import 'package:homeventory/features/reminders/data/timezone_name.dart';

void main() {
  const known = {
    'UTC',
    'Asia/Jakarta',
    'Asia/Ho_Chi_Minh',
    'America/New_York',
    'Etc/GMT-7',
    'Etc/GMT',
  };

  test('keeps IANA names the timezone database already has', () {
    expect(
      resolveTimeZoneName('Asia/Jakarta', knownNames: known),
      'Asia/Jakarta',
    );
  });

  test('maps GMT+07:00 onto Etc/GMT-7', () {
    expect(resolveTimeZoneName('GMT+07:00', knownNames: known), 'Etc/GMT-7');
  });

  test('maps deprecated Asia/Saigon onto Ho Chi Minh', () {
    expect(
      resolveTimeZoneName('Asia/Saigon', knownNames: known),
      'Asia/Ho_Chi_Minh',
    );
  });

  test('falls back to UTC when the id is unknown', () {
    expect(resolveTimeZoneName('Not/AZone', knownNames: known), 'UTC');
    expect(resolveTimeZoneName('  ', knownNames: known), 'UTC');
  });
}
