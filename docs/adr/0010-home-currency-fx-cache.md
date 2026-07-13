# ADR 0010: Home-currency FX cache via Frankfurter

- Status: Accepted
- Date: 2026-07-13

## Context

The home dashboard estimated inventory value must sum **all** priced items in the **home currency** (`homes.default_currency`). Items may be recorded in IDR, THB, USD, or other ISO codes. Changing display preference later must not overwrite item or home currency.

UAT follow-up Phase I required a provider-independent exchange-rate cache with stale/offline fallback.

## Decision

1. **Cache table** `exchange_rates` in Postgres: `base_currency`, `quote_currency`, `rate` (1 base = rate quote), `rate_date`, `provider`, `retrieved_at`, `expires_at`.
2. **Default provider:** open-source **Frankfurter** (`api.frankfurter.dev`) serving ECB reference rates. No API key in the APK.
3. **Refresh path:** Flutter `ExchangeRateService` fetches rates when dashboard stats load and needed pairs are missing/stale (>24h), then upserts via `upsert_exchange_rate` RPC.
4. **Aggregation:** `home_dashboard_stats` groups `purchase_price` by source currency, converts each subtotal once with `convert_currency_amount`, then sums in home currency. Null item currency is treated as home currency.
5. **Missing rates:** those items are excluded from the total and reported as `unconverted_item_count` / `value_is_partial` — never invent numbers.
6. **Disclosure:** UI shows home currency, FX rate date, and stale/unconverted hints.

## Consequences

### Positive

- Matches product rule: dashboard total = home currency.
- Item prices stay in original currency.
- Provider is swappable via `provider` column / ADR update.
- Offline continues with cached rates.

### Negative / trade-offs

- Client-triggered refresh (not Edge cron yet); needs network once per day per foreign set.
- ECB coverage is major currencies only; exotic codes may remain unconverted.
- Public Frankfurter availability is best-effort unless we self-host later.

## Alternatives considered

- Sum only home-currency rows (Phase C stub) — rejected; understates mixed inventories.
- Live FX per item from the client — rejected; slow, rate-limit risk, no auditability.
- Paid FX SaaS as default — deferred; Frankfurter is enough for household valuation.

## Related

- [`../UAT_PHASE6_SUPER_FOLLOWUP.md`](../UAT_PHASE6_SUPER_FOLLOWUP.md) §I
- Migration `20260713000200_exchange_rates_home_value.sql`
- `mobile/lib/features/homes/data/exchange_rate_service.dart`
