import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String generateInviteToken({int length = 40}) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

String sha256Hex(String input) {
  final digest = sha256.convert(utf8.encode(input));
  return digest.toString();
}

String generateShortCode({int length = 8}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}
