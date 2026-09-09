# Architecture — IAM Identity Lifecycle & QA Lab

This document describes **how** the requirements in `requirements.md` are
implemented. It does not restate the business scenario or requirements —
see `business-scenario.md` and `requirements.md` for the WHAT.

## 1. Architecture Overview

```
                         HR SOURCE
                       employees.csv
                            │
                            ▼
                    PowerShell Scripts
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
      Set-DepartmentMembership    Set-RoleMembership
              │                           │
              ▼                           ▼
           Groups                      Roles
              │                           │
              └─────────────┬─────────────┘
                            ▼
                    Keycloak — acme realm
                            │
                 ┌──────────┴──────────┐
                 ▼                     ▼
             acme-web               acme-api
          (login, public          (protected resource,
           client, browser)        introspection client)
                                       │
                                       ▼
                              Authorization decision
                              per request (role/group)
```

Two provisioning functions (`Set-DepartmentMembership`,
`Set-RoleMembership`) instead of one combined function, so that
department changes and role changes remain independently traceable
(REQ-008, REQ-009).

## 2. Keycloak Realm

- Realm name: `acme`
- Purpose: isolation boundary for this lab — all users, groups, roles,
  and clients for Acme Technologies live in this single realm. No
  cross-realm concerns for this project's scope.

**Implementation environment:** Keycloak `26.7.3`, run via Docker
(`quay.io/keycloak/keycloak:26.7.3`, `start-dev` mode), version pinned
explicitly (not `:latest`) so that REQ-012 verification results can
always be tied to a specific, reproducible Keycloak version.

## 3. Clients

| Client      | Type                        | Purpose                                                             |
|-------------|-----------------------------|-----------------------------------------------------------------------|
| `acme-web`  | Public, authorization code  | Demonstrates interactive human login (browser), issues tokens to test with. |
| `acme-api`  | Confidential                | The protected resource. Validates every request via token introspection against Keycloak. Requires a client secret. |

`acme-api` must be confidential (not public) because token introspection
(RFC 7662) requires the calling client to authenticate itself to
Keycloak — see Section 12 (Secrets).

## 4. Groups (Departments)

`department-it`, `department-hr`, `department-finance`,
`department-sales`.

An employee belongs to exactly one department group at a time
(REQ-003). Mover logic (REQ-008) must remove the previous group before
or atomically with adding the new one — never leave two department
groups assigned simultaneously.

## 5. Roles

| Role       | Assigned by          | Notes                                                        |
|------------|-----------------------|----------------------------------------------------------------|
| `employee` | HR feed (automated)  | Baseline — every active employee holds this (REQ-004).        |
| `manager`  | HR feed (automated)  | **Additive** to `employee`, never a replacement (REQ-005).    |
| `hr-admin` | IAM Administrator only | Never HR-feed-driven (REQ-006).                              |
| `it-admin` | IAM Administrator only | Never HR-feed-driven (REQ-006).                              |

## 6. Authentication & Token Model

**Decision:** `acme-api` validates every request via Keycloak token
introspection, rather than local (offline) JWT signature validation.

```
Client
  │  Access Token
  ▼
acme-api
  │  introspection call (client-authenticated)
  ▼
Keycloak
  ├── active = true  → request proceeds to authorization check
  └── active = false → 401
```

**Reason:** the project prioritizes deterministic, repeatable testing of
immediate post-termination access behavior over production-scale
performance.

**Trade-off:** an extra network call on every protected request,
compared with local JWT validation.

**Alternative considered:** short-lived access tokens (e.g. 30–60s)
with offline JWT validation. Rejected for this lab because
expiry-based testing introduces timing dependencies (tests would need
to wait out a TTL window) and only proves a *bounded* exposure window,
not immediate revocation.

**Implementation note (found during setup verification):** Keycloak
does not include group membership in tokens or introspection
responses by default — only realm roles are included automatically.
A dedicated `groups` client scope with a "Group Membership" mapper
(`Full group path` off, added to access token, ID token, userinfo,
**and token introspection**) must be created and attached as a
**default** scope to both `acme-web` and `acme-api`. Without the
introspection toggle specifically enabled on this mapper, `acme-api`
would never see group membership at all, since it never reads tokens
locally.

## 7. `acme-api` as Protected Resource

A small API is sufficient — it does not need to be a real backend, only
enough to make authorization decisions observable and testable. Example
endpoints (one per functional area referenced in the business
scenario):

| Endpoint            | Required group/role                          | Requirement(s) |
|----------------------|-----------------------------------------------|-----------------|
| `GET /hr/data`       | `department-hr`                               | Supporting endpoint; no dedicated requirement |
| `GET /finance/data`  | `department-finance`                          | REQ-014         |
| `GET /it/data`       | `department-it`                               | REQ-013         |
| `GET /it/admin`      | `department-it` **and** `it-admin`            | REQ-016         |
| `GET /manager/dashboard` | `manager`                                 | REQ-015         |
| `GET /whoami`        | any authenticated (active) token              | REQ-012 baseline check |

`/whoami` is deliberately the simplest possible endpoint — it is the
one used for the REQ-012 session-revocation test, so it should have no
authorization logic beyond "is this token still active", keeping that
specific test isolated from group/role authorization concerns.

## 8. JML Provisioning Architecture

PowerShell scripts, run against `employees.csv`:

- `provision-users.ps1` — Joiner. Reads new `Active` records, creates
  identities, calls `Set-DepartmentMembership` and
  `Set-RoleMembership`.
- `update-users.ps1` — Mover. Diffs current Keycloak state against the
  HR feed per employee; calls `Set-DepartmentMembership` and/or
  `Set-RoleMembership` independently, only for the dimension(s) that
  changed.
- `deprovision-users.ps1` — Leaver. Handles REQ-010/011/012 (see
  Section 10).

Admin roles (`hr-admin`, `it-admin`) are **not** touched by any of
these scripts (REQ-006) — they are out of scope for HR-feed-driven
automation entirely.

## 9. Joiner / Mover / Leaver Flows

```
JOINER                MOVER                    LEAVER
  │                      │                         │
Create identity    ┌─────┴─────┐            Disable account (REQ-010)
  │                ▼           ▼                   │
Department + Role  Dept change  Role change   Revoke groups/roles (REQ-011)
  │                (REQ-008)   (REQ-009)            │
Access granted      independent, can           Revoke active session (REQ-012)
(REQ-007)            co-occur                        │
                                                 Access denied
```

## 10. Session/Token Revocation for REQ-012

**This section intentionally does not assert a mechanism as fact.**
Whether disabling a Keycloak user automatically invalidates existing
sessions, or whether an explicit session/logout call is required, will
be **verified empirically** during implementation against the specific
Keycloak version used — not assumed from documentation.

Planned Leaver sequence:
```
HR = Terminated
       │
       ├── Disable account         (REQ-010)
       ├── Remove groups/roles     (REQ-011)
       └── Invalidate active sessions via Keycloak admin API
                                    (REQ-012 — mechanism TBD/verified)
```

If the first implementation attempt turns out to leave existing
sessions valid after disable, that is treated as a genuine defect
(e.g. `DEF-001 — Terminated user's existing session remains usable`),
not silently patched into the test. This is deliberate: it produces a
Requirement → Test → Failure → Defect → Fix → Regression cycle, which
is a stronger demonstration of QA process than a lab that "just
worked" on the first try.

## 11. Authorization Mapping

See the table in Section 7. Each protected endpoint's required
group/role combination is the single source of truth for both the API
implementation and the manual/automated test cases derived from it.

## 12. Secrets / Configuration

Never committed to the repository (`.gitignore` already excludes
`.env` / `*.env`):

- `acme-api` client secret (needed for introspection calls)
- Keycloak admin credentials used by the PowerShell provisioning
  scripts

A `.env.example` (committed, with placeholder values only) should be
added once implementation starts, so the required variables are
documented without exposing real values.

## 13. Traceability — Requirements → Architecture Components

| Requirement(s) | Architecture component |
|-----------------|--------------------------|
| REQ-001, REQ-002 | `provision-users.ps1` (Joiner) |
| REQ-003 | Groups model (Section 4) + `Set-DepartmentMembership` |
| REQ-004, REQ-005, REQ-006 | Roles model (Section 5) + `Set-RoleMembership` |
| REQ-007 | Joiner flow (Section 9) |
| REQ-008 | Mover — department (Section 9) |
| REQ-009 | Mover — role (Section 9) |
| REQ-010, REQ-011 | Leaver — account/access (Section 10) |
| REQ-012 | Leaver — session revocation + introspection model (Sections 6, 10) |
| REQ-013–REQ-016 | `acme-api` authorization mapping (Sections 7, 11) |
| REQ-017 | Cross-cutting — verified by regression across Mover/Leaver test suites |

## 14. Architectural Decisions & Trade-offs

**Decision 1 — Model access as two independent dimensions (department
Group × business Role), not combined roles** (e.g. `it-manager`,
`finance-employee`).

- *Reason:* keeps department changes and role changes independently
  traceable and testable (REQ-008/REQ-009); scales additively
  (N departments + M levels) rather than multiplicatively (N×M roles)
  as the organization grows.
- *Trade-off:* authorization logic must combine two dimensions at
  evaluation time, rather than reading one self-explanatory role name.
- *Alternative considered:* combined per-department-per-level roles.
  Rejected due to role explosion at scale.

**Decision 2 — `acme-api` uses token introspection, not offline JWT
validation.** See Section 6 for the full Decision/Reason/Trade-off.

**Decision 3 — Explicit dual role assignment (`employee` + `manager`),
not composite/hierarchical roles.**

- *Reason:* keeps REQ-009 role downgrade unambiguous — an explicitly
  assigned `employee` role survives removal of `manager`, whereas an
  implied (composite-inherited) role would disappear along with it.
- *Trade-off:* more explicit assignments needed per user compared to a
  composite hierarchy; does not scale as gracefully to many role
  levels.
- *Alternative considered:* composite roles — the same pattern OIM
  uses for hierarchical Business Roles. Rejected here specifically
  because the project has only two levels, so the
  administrative-overhead benefit of composites doesn't outweigh the
  testability cost.

**Decision 4 — JML provisioning scripts authenticate to the Keycloak
Admin REST API via a dedicated service account client
(`acme-provisioner`), never a personal administrator account.**

- *Reason:* least privilege applies to automation and integration
  accounts, not only end users (the same principle behind REQ-017).
  Automation should not depend on, or require, a personal
  administrator identity, and should hold only the specific
  administrative permissions it needs — the same role a connector
  account plays against a target system in a real IGA deployment
  (e.g. OIM).
- *Trade-off:* more setup than reusing an existing admin account;
  requires deliberately scoping the service account's permissions
  rather than granting broad access by default.
- *Secret handling:* the client secret is never committed to the
  repository. Locally it is read from an environment variable
  (`KEYCLOAK_CLIENT_SECRET`); in CI (GitHub Actions, once built) it
  will come from GitHub Actions Secrets. Credentials are
  configuration/secrets, not source code.

## Known Limitations

- **Test identities are not part of the exported configuration.**
  `realm-export.json` captures the reproducible IAM configuration
  (realm, groups, roles, clients) via Keycloak's partial export, which
  does not include users. The four test identities (Maria, Nikos,
  Giorgos, Eleni) are created manually for verification purposes and
  are not treated as persistent infrastructure — no credentials or
  test-user data are stored in the repository. On a fresh environment,
  test identities are recreated manually as needed. Whether to
  provision them programmatically is a decision deferred to the
  automation phase, not solved here.

- **Direct Access Grants (ROPC) are enabled on `acme-web` solely for
  testing convenience via Postman, avoiding the need to build a
  browser-based frontend for this lab.** ROPC is discouraged in modern
  OAuth 2.0 practice and is not included in OAuth 2.1, because it
  requires the client to handle the user's credentials directly and
  prevents the authorization server from providing some of the
  protections available through browser-based authorization flows. It
  also has important limitations around MFA and external
  identity-provider scenarios. This configuration is acceptable for
  the controlled lab environment and should not be considered a
  production recommendation. A hardened deployment would use an
  appropriate Authorization Code-based flow and disable Direct Access
  Grants.

- **CSV as the HR source** is a deliberate simplification for lab
  scope. It has no producer authentication, no integrity check, no
  audit trail, and is inherently batch rather than event-driven. A
  production system would use a direct, authenticated connector
  (SCIM/LDAP/API) to the HR system. This does not affect the validity
  of the IAM/QA work demonstrated here — CSV-based bootstrap connectors
  are also a real, documented pattern in production IAM
  implementations.
