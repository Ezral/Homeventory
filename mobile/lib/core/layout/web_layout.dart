import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Desktop web breakpoint. Narrow browser windows keep the phone UI
/// (bottom nav); wide windows get the sidebar + panes chrome.
const double kWebDesktopBreakpoint = 900;

/// True when running in a **wide** browser viewport.
///
/// - Android / iOS: always false (native mobile chrome).
/// - Web phone / narrow window: false → mobile GUI.
/// - Web desktop / wide window: true → sidebar + panes.
bool isWebDesktopLayout(BuildContext context) {
  if (!kIsWeb) return false;
  return MediaQuery.sizeOf(context).width >= kWebDesktopBreakpoint;
}

/// How many search-result cards fit in a row.
///
/// Grows with available width up to **4** columns when there are multiple
/// hits. A single match stays one card wide. Narrow phones stay one column.
int searchResultColumnCount({
  required double availableWidth,
  required int resultCount,
}) {
  if (resultCount <= 1) return 1;
  const minCardWidth = 240.0;
  const maxColumns = 4;
  var columns = (availableWidth / minCardWidth).floor();
  if (columns < 1) columns = 1;
  if (columns > maxColumns) columns = maxColumns;
  if (columns > resultCount) columns = resultCount;
  return columns;
}

/// Parses `/homes/:homeId/...` excluding `/homes/new` and `/homes/join`.
String? homeIdFromLocation(String location) {
  final match = RegExp(r'^/homes/([^/?#]+)').firstMatch(location);
  if (match == null) return null;
  final id = match.group(1);
  if (id == null || id == 'new' || id == 'join') return null;
  return id;
}
