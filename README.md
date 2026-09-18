# IAM Identity Lifecycle & QA Lab

A small, local IAM lab (Keycloak + Docker) simulating employee
identity lifecycle management (Joiner–Mover–Leaver) for a fictional
company, built to demonstrate the bridge between IAM engineering and
manual/automated QA.

Every architectural decision with a real trade-off is recorded as an
individual, numbered Architecture Decision Record in
[`docs/decisions/`](docs/decisions/) — not just what was built, but
why, what alternatives were considered, and what was found empirically
along the way.

## Status

- [x] Business scenario ([`docs/business-scenario.md`](docs/business-scenario.md))
- [x] Requirements baseline — 17 requirements ([`docs/requirements.md`](docs/requirements.md))
- [x] IAM architecture design — realm, clients, groups, roles, token
      model ([`docs/architecture.md`](docs/architecture.md), 7 ADRs)
- [x] Local environment — Docker + Keycloak 26.7.3, with the realm
      configuration reproducible via `keycloak/realm-export.json`
- [x] JML identity lifecycle automation (PowerShell) — REQ-007
      through REQ-012, all implemented and empirically verified:
  - [x] Joiner (`provision-users.ps1`) — identity creation, department
        and role assignment, idempotent
  - [x] Mover (`update-users.ps1`) — independent department and role
        change handling, idempotent
  - [x] Leaver (`deprovision-users.ps1`) — account deactivation,
        access revocation, and session revocation (the session
        revocation mechanism was verified empirically against live
        Keycloak behavior, not assumed — see `docs/architecture.md`
        Section 10)
- [x] Protected API (`acme-api`, Spring Boot 4.1.1) — OAuth2 Resource
      Server against Keycloak token introspection, 5 endpoints,
      verified end-to-end with real tokens (positive and negative
      cases for each):
  - [x] `/api/whoami` — REQ-012 baseline (any active token)
  - [x] `/api/it/data` — REQ-013 (department-based, group only)
  - [x] `/api/finance/data` — REQ-014 (department-based, group only)
  - [x] `/api/manager/dashboard` — REQ-015 (role only, independent
        of department)
  - [x] `/api/it/admin` — REQ-016 (group AND role together)
- [x] Test strategy ([`testing/test-strategy.md`](testing/test-strategy.md))
- [x] Test scenarios and manual test cases — 27 test cases,
      fully executed ([`testing/test-cases.md`](testing/test-cases.md))
- [x] Defect reports — 4 defects found during execution, all
      fixed, retested, and closed with regression evidence
      ([`testing/defects/`](testing/defects/)):
  - BUG-001 — username collision on duplicate first names (fixed
    per [ADR-0007](docs/decisions/0007-username-generation-strategy.md))
  - BUG-002 — Mover restored access for a Terminated employee
    (security-relevant; fixed by adding status-scoped responsibility
    to the Mover — see `docs/architecture.md` Section 8)
  - BUG-003 — role reconciliation reported "already correct" while
    the `employee` role was actually missing
  - BUG-004 — Joiner log showed a computed, not actual, username for
    already-existing employees
- [x] Regression testing — re-executed after each fix, alongside the
      initial full run
- [x] API testing — Postman collection covering authentication and
      authorization ([`postman/iam-qa-lab.postman_collection.json`](postman/iam-qa-lab.postman_collection.json))
- [x] Automated tests (Java 21 + JUnit 6 + REST Assured) — 11
      automated tests covering authorization (REQ-013–016) and
      session/token validity (REQ-012), the same API-testable
      subset as the Postman collection
      ([`automation/`](automation/))
- [ ] CI (GitHub Actions)

## Local Setup

Reproducing this environment from a fresh clone takes a few steps —
most are fully automated from committed artifacts, one is
deliberately manual:

1. `docker compose up -d` — starts Keycloak 26.7.3, with the `acme`
   realm (groups, roles, clients, mappers) automatically imported
   from `keycloak/realm-export.json`.
2. `.\scripts\provision-users.ps1` — creates the test identities
   from `data/employees.csv` (department + role assignment), via the
   Joiner automation.
3. **Set a password for each created identity, manually, via
   Keycloak Admin Console** (Users → select user → Credentials tab).
   This step is intentionally not automated — no script or CI step
   in this repository sets or stores real passwords, since doing so
   would mean either hardcoding a credential or building a secrets
   pipeline disproportionate to this lab's scope.
4. `cd acme-api && mvn spring-boot:run` — starts the protected API on
   `localhost:8081` (needs `ACME_API_CLIENT_SECRET` set as an
   environment variable first — see Admin Console → Clients →
   acme-api → Credentials).
5. Import `postman/iam-qa-lab.postman_collection.json` into Postman,
   fill in the `REPLACE_ME` password fields with what you set in
   step 3, run the Authentication requests first.

Steps 1–2 and 4 are fully reproducible from what's committed here.
Step 3 is a genuine manual credential-provisioning step, consistent
with never storing real passwords in the repository.

## Repository structure

```
docs/
├── business-scenario.md
├── requirements.md
├── architecture.md
└── decisions/          # individual ADRs
keycloak/
└── realm-export.json   # reproducible IAM configuration (no users)
data/
└── employees.csv       # HR source feed
scripts/                # PowerShell JML automation
acme-api/                # Spring Boot protected resource
docker-compose.yml
```

## Tech stack

- **Keycloak 26.7.3** (Docker) — identity provider / target system
- **PowerShell** — JML provisioning automation, acting as the
  connector layer a real IGA product (e.g. One Identity Manager)
  would otherwise provide
- **Java 21 + Spring Boot 4.1.1** — `acme-api`, the protected resource
  that consumes the IAM model via token introspection
- **Postman** — manual API/IAM verification
- **Git / GitHub** — version control, with a commit history that
  follows the project's actual build order
