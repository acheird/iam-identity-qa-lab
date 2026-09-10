# ADR-0002: `acme-api` uses token introspection, not offline JWT validation

## Status
Accepted

## Context
REQ-012 requires that a terminated employee's already-open session
must not continue to grant access. `acme-api` needs a way to validate
incoming access tokens on every request; the two realistic options are
(a) online token introspection against Keycloak (RFC 7662), or
(b) offline/local JWT signature validation with short-lived tokens.

## Decision
`acme-api` validates every request via Keycloak token introspection,
rather than local (offline) JWT signature validation. See
`architecture.md` Section 6 for the request flow diagram.

## Consequences
- **Benefit:** deterministic, repeatable testing of immediate
  post-termination access behavior — a REQ-012 test is simply
  "revoke, then immediately assert 401", no timing dependency.
- **Trade-off:** an extra network call on every protected request,
  compared with local JWT validation — acceptable at this project's
  scale, would need reconsideration at production scale.
- **Alternative considered:** short-lived access tokens (e.g. 30–60s)
  with offline JWT validation. Rejected for this lab because
  expiry-based testing introduces timing dependencies (tests would
  need to wait out a TTL window) and only proves a *bounded* exposure
  window, not immediate revocation.
- **Follow-on requirement:** this decision requires the `acme-api`
  client to be confidential (RFC 7662 introspection requires client
  authentication) — see `architecture.md` Section 3.
