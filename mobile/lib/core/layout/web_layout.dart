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

/// Parses `/homes/:homeId/...` excluding `/homes/new` and `/homes/join`.
String? homeIdFromLocation(String location) {
  final match = RegExp(r'^/homes/([^/?#]+)').firstMatch(location);
  if (match == null) return null;
  final id = match.group(1);
  if (id == null || id == 'new' || id == 'join') return null;
  return id;
}
