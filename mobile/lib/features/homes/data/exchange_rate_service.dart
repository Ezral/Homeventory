import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Refreshes cached FX rates from Frankfurter (ECB) into Supabase.
///
/// Rates mean: 1 [base] = rate [quote]. For each foreign currency F and home
/// currency H we store both (F→H) and (H→F) when the API returns H→F.
class ExchangeRateService {
  ExchangeRateService({
    required this.client,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final SupabaseClient client;
  final http.Client _http;

  static const _provider = 'frankfurter';
  static final _endpoint = Uri.parse('https://api.frankfurter.dev/v1/latest');

  /// Ensures rates exist to convert [foreignCurrencies] into [homeCurrency].
  /// No-ops when there are no foreign currencies.
  Future<void> ensureRatesToHome({
    required String homeCurrency,
    required Iterable<String> foreignCurrencies,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final home = homeCurrency.trim().toUpperCase();
    final needed = foreignCurrencies
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.isNotEmpty && c != home)
        .toSet()
        .toList()
      ..sort();

    if (needed.isEmpty) return;

    final missingOrStale = <String>[];
    for (final from in needed) {
      final fresh = await _hasFreshRate(from: from, to: home, maxAge: maxAge);
      if (!fresh) missingOrStale.add(from);
    }
    if (missingOrStale.isEmpty) return;

    await _fetchAndUpsert(homeCurrency: home, symbols: missingOrStale);
  }

  Future<bool> _hasFreshRate({
    required String from,
    required String to,
    required Duration maxAge,
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(maxAge).toIso8601String();
    final row = await client
        .from('exchange_rates')
        .select('id')
        .eq('base_currency', from)
        .eq('quote_currency', to)
        .eq('provider', _provider)
        .gte('retrieved_at', cutoff)
        .maybeSingle();
    if (row != null) return true;

    final inverse = await client
        .from('exchange_rates')
        .select('id')
        .eq('base_currency', to)
        .eq('quote_currency', from)
        .eq('provider', _provider)
        .gte('retrieved_at', cutoff)
        .maybeSingle();
    return inverse != null;
  }

  Future<void> _fetchAndUpsert({
    required String homeCurrency,
    required List<String> symbols,
  }) async {
    if (symbols.isEmpty) return;

    final uri = _endpoint.replace(
      queryParameters: {
        'base': homeCurrency,
        'symbols': symbols.join(','),
      },
    );

    final response = await _http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Frankfurter FX refresh failed (${response.statusCode}): '
        '${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rateDateRaw = body['date'] as String?;
    final rateDate = rateDateRaw == null
        ? DateTime.now().toUtc()
        : DateTime.parse(rateDateRaw);
    final rates = Map<String, dynamic>.from(body['rates'] as Map? ?? {});
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 24));

    for (final entry in rates.entries) {
      final foreign = entry.key.toUpperCase();
      final homeToForeign = (entry.value as num).toDouble();
      if (homeToForeign <= 0) continue;

      // API: 1 home = homeToForeign foreign
      await client.rpc(
        'upsert_exchange_rate',
        params: {
          'p_base_currency': homeCurrency,
          'p_quote_currency': foreign,
          'p_rate': homeToForeign,
          'p_rate_date': rateDate.toIso8601String().split('T').first,
          'p_provider': _provider,
          'p_expires_at': expiresAt.toIso8601String(),
        },
      );

      // Inverse: 1 foreign = 1/homeToForeign home (for dashboard convert)
      await client.rpc(
        'upsert_exchange_rate',
        params: {
          'p_base_currency': foreign,
          'p_quote_currency': homeCurrency,
          'p_rate': 1.0 / homeToForeign,
          'p_rate_date': rateDate.toIso8601String().split('T').first,
          'p_provider': _provider,
          'p_expires_at': expiresAt.toIso8601String(),
        },
      );
    }
  }
}
