# IAM Identity Lifecycle & QA Lab

A small, self-contained IAM lab (Keycloak + Docker) simulating employee
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
      model ([`docs/architecture.md`](docs/architecture.md), 6 ADRs)
- [x] Local environment — Docker + Keycloak 26.7.3, reproducible via
      `keycloak/realm-export.json`
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
- [ ] Protected API (`acme-api`, Spring Boot 4.1.1) — Resource Server
      configured against Keycloak token introspection; endpoints not
      yet implemented
- [ ] Test strategy
- [ ] Manual test cases & execution
- [ ] Defect reports
- [ ] Regression testing
- [ ] API testing (Postman)
- [ ] Automated tests (Java + REST Assured/JUnit)
- [ ] CI (GitHub Actions)

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
acme-api/                # Spring Boot protected resource (in progress)
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
