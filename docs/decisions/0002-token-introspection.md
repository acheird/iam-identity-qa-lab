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

## Addendum — audience requirement (empirical finding)

The introspection endpoint needs to be able to associate the token
with the client/resource server performing the introspection. In this
setup, that means `acme-api` must appear in the access token's
`aud` (audience) claim.

```
Eleni
  ↓
acme-web
  ↓
Access Token
  ↓
audience = acme-api
  ↓
acme-api introspection
  ↓
active = true
```

**What happened:** introspection initially returned `active: false`
for freshly issued, unexpired tokens — confirmed healthy via a
successful `/userinfo` call with the same token. The Keycloak event
log showed the real cause directly:
`error="invalid_token", reason="Client 'acme-api' is not in the
token audience", token_issued_for="acme-web"`.

**Fix:** a dedicated `audience-acme-api` client scope, with an
"Audience" protocol mapper (Included Client Audience: `acme-api`),
attached as a **default** scope to `acme-web`, so every token it
issues includes `acme-api` in `aud`.

**Why this matters:** without it, introspection by `acme-api` would
never succeed for any `acme-web`-issued token, regardless of the
token's actual validity — this is a hard prerequisite for the
introspection design above to function at all, not an edge case.

**Diagnostic note:** three other explanations were considered and
ruled out first (token corruption in copy-paste, wrong client secret,
a missing `openid` scope causing a separate, unrelated `/userinfo`
403) before the real cause was confirmed directly from the Keycloak
event log — not inferred from Postman responses alone.

**Scope of this finding:** this confirms only that a freshly issued
token introspects as `active: true` before any Leaver action. It is
the REQ-012 baseline, not a conclusion — the real REQ-012 test
(does the *same* token still introspect as active *after*
termination/logout) is still ahead.

## Verification / Outcome

The full discovery chain, in order:

```
Audience configuration missing
        ↓
introspection unusable (active: false for valid tokens)
        ↓
audience mapper added
        ↓
fresh token → introspection: active: true
        ↓
explicit session logout (POST /users/{id}/logout)
        ↓
same token → introspection: no longer active
        ↓
REQ-012 confirmed satisfied — see architecture.md Section 10
```

The session-revocation experiment (Eleni, E004) confirmed that after
explicit session logout, the same previously issued token was no
longer reported as active by Keycloak introspection — this is the
scoped, empirically-supported claim; see Section 10 of
`architecture.md` for the full evidence and for what is deliberately
*not* claimed about Keycloak's internal mechanism.
