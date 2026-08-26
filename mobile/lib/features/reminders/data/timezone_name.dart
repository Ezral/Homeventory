/// Map an OS timezone id onto a name the `timezone` package knows.
///
/// Android can return IANA ids (`Asia/Jakarta`) or `GMT+07:00`. Unknown names
/// must not throw — scheduling would otherwise abort and no alerts would fire.
String resolveTimeZoneName(String raw, {Iterable<String>? knownNames}) {
  final name = raw.trim();
  if (name.isEmpty) return 'UTC';
  final known = knownNames == null
      ? null
      : knownNames is Set<String>
      ? knownNames
      : knownNames.toSet();
  bool isKnown(String candidate) =>
      known == null ? true : known.contains(candidate);

  if (isKnown(name)) return name;

  const aliases = {
    'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    'US/Eastern': 'America/New_York',
    'US/Central': 'America/Chicago',
    'US/Mountain': 'America/Denver',
    'US/Pacific': 'America/Los_Angeles',
    'US/Alaska': 'America/Anchorage',
    'US/Hawaii': 'Pacific/Honolulu',
  };
  final aliased = aliases[name];
  if (aliased != null && isKnown(aliased)) return aliased;

  final gmt = RegExp(r'^GMT([+-])(\d{1,2})(?::?(\d{2}))?$').firstMatch(name);
  if (gmt != null) {
    final sign = gmt.group(1)!;
    final hours = int.parse(gmt.group(2)!);
    if ((gmt.group(3) ?? '00') == '00') {
      // Etc/GMT uses inverted signs: GMT+7 → Etc/GMT-7.
      final inverted = sign == '+' ? '-' : '+';
      final etc = hours == 0 ? 'Etc/GMT' : 'Etc/GMT$inverted$hours';
      if (isKnown(etc)) return etc;
    }
  }

  return isKnown('UTC') ? 'UTC' : name;
}
