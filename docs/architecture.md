# Architecture — IAM Identity Lifecycle & QA Lab

This document describes **how** the requirements in `requirements.md` are
implemented. It does not restate the business scenario or requirements —
see `business-scenario.md` and `requirements.md` for the WHAT.

Architectural decisions with real trade-offs (why we chose X over Y)
live as individual Architecture Decision Records in
[`decisions/`](decisions/), not inline in this document. This file
describes the resulting design and links to the relevant ADR wherever
a design choice needs justification.

| ADR | Decision |
|---|---|
| [0001](decisions/0001-orthogonal-group-role-model.md) | Independent Group/Role model, not combined roles |
| [0002](decisions/0002-token-introspection.md) | `acme-api` uses token introspection, not offline JWT |
| [0003](decisions/0003-explicit-dual-role-assignment.md) | Explicit dual role assignment, not composite roles |
| [0004](decisions/0004-dedicated-service-account.md) | Dedicated service account for automation |
| [0005](decisions/0005-manage-users-coarse-grained-permission.md) | `manage-users` accepted as coarse-grained least privilege |
| [0006](decisions/0006-ropc-for-testing-convenience.md) | ROPC enabled on `acme-web` for testing only |

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
(REQ-008, REQ-009) — see [ADR-0001](decisions/0001-orthogonal-group-role-model.md).

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

| Client              | Type          | Purpose                                                                 |
|----------------------|---------------|---------------------------------------------------------------------------|
| `acme-web`          | Public        | Interactive human login (browser). Direct Access Grants also enabled for testing — see [ADR-0006](decisions/0006-ropc-for-testing-convenience.md). |
| `acme-api`          | Confidential  | The protected resource. Validates every request via token introspection — see [ADR-0002](decisions/0002-token-introspection.md). |
| `acme-provisioner`  | Confidential  | Service account used by the JML PowerShell scripts to call the Admin REST API — see [ADR-0004](decisions/0004-dedicated-service-account.md) and [ADR-0005](decisions/0005-manage-users-coarse-grained-permission.md). |

`acme-api` and `acme-provisioner` must be confidential (not public)
because token introspection (RFC 7662) and the Client Credentials
grant both require the calling client to authenticate itself to
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
| `manager`  | HR feed (automated)  | **Additive** to `employee`, never a replacement (REQ-005). See [ADR-0003](decisions/0003-explicit-dual-role-assignment.md). |
| `hr-admin` | IAM Administrator only | Never HR-feed-driven (REQ-006).                              |
| `it-admin` | IAM Administrator only | Never HR-feed-driven (REQ-006).                              |

## 6. Authentication & Token Model

`acme-api` validates every request via Keycloak token introspection
rather than local (offline) JWT signature validation — see
[ADR-0002](decisions/0002-token-introspection.md) for the full
rationale and trade-off.

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

**Configuration note (found during setup verification):** Keycloak
does not include group membership in tokens or introspection
responses by default — only realm roles are included automatically.
A dedicated `groups` client scope with a "Group Membership" mapper
(`Full group path` off, added to access token, ID token, userinfo,
**and token introspection**) must be created and attached as a
**default** scope to both `acme-web` and `acme-api`. Without the
introspection toggle specifically enabled on this mapper, `acme-api`
would never see group membership at all, since it never reads tokens
locally.

**Configuration note — declarative User Profile (Keycloak 26.x):**
custom user attributes (e.g. `employeeId`, used to anchor REQ-002
uniqueness — see Section 8) are **not** freely settable key-value
pairs. Keycloak 26's declarative User Profile requires an attribute to
be explicitly declared under Realm settings → User profile before it
can be set on any user, via either the Admin Console or the Admin REST
API. `employeeId` is declared with Admin-only view/edit permissions
(end users cannot edit their own employee ID).

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

PowerShell scripts, run against `employees.csv`, authenticating as
`acme-provisioner` ([ADR-0004](decisions/0004-dedicated-service-account.md)):

- `provision-users.ps1` — Joiner. Reads new `Active` records, creates
  identities, calls `Set-DepartmentMembership` and
  `Set-RoleMembership`. Identity uniqueness (REQ-002) is anchored to
  the `employeeId` custom user attribute, not to username or name —
  two employees could share a first name. Username is a
  human-readable login identifier only.
- `update-users.ps1` — Mover. Diffs current Keycloak state against the
  HR feed per employee; calls `Set-DepartmentMembership` and/or
  `Set-RoleMembership` independently, only for the dimension(s) that
  changed.
- `deprovision-users.ps1` — Leaver. Handles REQ-010/011/012 (see
  Section 10).

Admin roles (`hr-admin`, `it-admin`) are **not** touched by any of
these scripts (REQ-006) — they are out of scope for HR-feed-driven
automation entirely.

**Operations matrix** (what each script actually does, and how it is
enforced at the Keycloak permission level — see
[ADR-0005](decisions/0005-manage-users-coarse-grained-permission.md)):

| Operation | Joiner | Mover | Leaver | Keycloak enforcement |
|---|---|---|---|---|
| Find user | ✓ | ✓ | ✓ | `manage-users` |
| Read user | ✓ | ✓ | ✓ | `manage-users` |
| Create user | ✓ | — | — | `manage-users` |
| Update user | — | ✓ | ✓ | `manage-users` |
| Add/remove groups | ✓ | ✓ | — | `manage-users` |
| Look up realm role definitions | ✓ | ✓ | — | `view-realm` (found empirically — see ADR-0005) |
| Add/remove roles | ✓ | ✓ | — | `manage-users` |
| Disable account | — | — | ✓ | `manage-users` |
| Delete user | ❌ | ❌ | ❌ | *not enforceable with a built-in role — see ADR-0005* |

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
- `acme-provisioner` client secret (needed for the Admin REST API)
- Keycloak admin credentials used for initial bootstrap

`.env.example` (committed, with placeholder values only) documents the
required variables without exposing real values.

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

## Known Limitations / Scope Notes

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

- **CSV as the HR source** is a deliberate simplification for lab
  scope. It has no producer authentication, no integrity check, no
  audit trail, and is inherently batch rather than event-driven. A
  production system would use a direct, authenticated connector
  (SCIM/LDAP/API) to the HR system. This does not affect the validity
  of the IAM/QA work demonstrated here — CSV-based bootstrap connectors
  are also a real, documented pattern in production IAM
  implementations.
