# ADR-0007: `acme-web` tokens require an explicit audience mapper for `acme-api`

## Status
Accepted

## Context
[ADR-0002](0002-token-introspection.md) established that `acme-api`
validates every request via Keycloak token introspection. During
REQ-012 experimentation (verifying whether a terminated user's
already-issued token remains usable), introspection consistently
returned `active: false` for tokens that were otherwise valid and
unexpired — confirmed healthy via a successful `/userinfo` call using
the same token.

## Decision
Add a dedicated `audience-acme-api` client scope with an "Audience"
protocol mapper (Included Client Audience: `acme-api`), attached as a
**default** scope to `acme-web`. This ensures every access token
issued via `acme-web` includes `acme-api` in its `aud` claim.

## Consequences
- **Empirical finding, not assumed:** Keycloak's token introspection
  endpoint rejects a token (`active: false`) if the introspecting
  client is not present in the token's audience, even when the token
  is otherwise valid and unexpired. Confirmed directly from the
  Keycloak event log:
  `error="invalid_token", reason="Client 'acme-api' is not in the
  token audience", token_issued_for="acme-web"`.
- **This is a hard prerequisite, not an edge case:** without this
  mapper, token introspection by `acme-api` would never succeed for
  any token issued by `acme-web`, regardless of the token's actual
  validity — making the entire introspection-based authorization
  model (ADR-0002) non-functional from the start.
- **No trade-off or alternative recorded here** — this is a required
  configuration step to make the already-chosen introspection design
  actually work, not a competing design choice.
- **Diagnostic note:** three other explanations were considered and
  ruled out before finding the real cause (token corruption in
  copy-paste, wrong client secret, missing `openid` scope causing a
  separate but unrelated `/userinfo` 403). The real cause was only
  confirmed by reading the Keycloak event log directly, not by
  inference from Postman responses alone — consistent with this
  project's practice of verifying Keycloak behavior empirically
  rather than assuming it.
