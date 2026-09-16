# Test Strategy — IAM Identity Lifecycle & QA Lab

This document describes **how** the system will be tested — it does
not restate requirements or architecture. See `docs/requirements.md`
and `docs/architecture.md` for those.

## 1. Scope

**In scope:**
- JML identity lifecycle (REQ-001–REQ-011): Joiner, Mover, Leaver,
  via the PowerShell automation
- Session/token revocation (REQ-012)
- Authorization behavior (REQ-013–REQ-016), via `acme-api`
- Least privilege / scope boundaries (REQ-017)

**Out of scope:**
- Keycloak's own internal correctness — treated as a trusted,
  independently-tested third-party system. We test our
  *configuration* of it (groups, roles, mappers), not Keycloak itself.
- Performance/load testing — not relevant at this project's scale.
- UI testing — no `acme-web` frontend was built; `acme-web` exists
  only as a Keycloak client for obtaining tokens (ADR-0006).

## 2. Test levels & approach

- **Manual testing** is the primary method for this project — direct
  verification via Keycloak Admin Console, Postman, and script
  output, cross-checked against each other (never trusting a single
  source, per the project's established practice).
- **Automated testing** covers a smaller, prioritized subset of the
  highest-value test cases (Java + REST Assured/JUnit), added later.
- **Approach:** black-box, requirement-driven. Every test case traces
  to a primary requirement ID (see Section 4 for the full traceability
  rule).

## 3. Test types

| Type | Example |
|---|---|
| Functional | Joiner creates identity + department + role together |
| Authorization | `/api/it/data` allows `department-it`, denies others |
| Negative | Wrong department, wrong role, missing token, revoked token |
| Edge case | Combined department+role change in the same Mover run |
| Regression | Re-running Joiner/Mover against an already-correct state (idempotency) |
| API | Postman collection covering authentication and authorization flows against `acme-api` |

## 4. Traceability

Every test case has a unique ID and a **primary** requirement ID from
`docs/requirements.md`. A test case may legitimately exercise more
than one requirement (common in lifecycle/authorization flows), but
each has exactly one primary requirement for traceability purposes.
The mapping is maintained directly in `testing/test-cases.md` (not
duplicated here) — no requirement should end up with zero test cases,
and no test case should exist without a requirement behind it.

## 5. Environment

- Keycloak 26.7.3 (Docker), realm reproducible from
  `keycloak/realm-export.json`
- `acme-api` (Spring Boot 4.1.1), `http://localhost:8081`
- PowerShell 7 automation scripts (`scripts/`)
- Postman, for manual authentication/authorization/API testing

## 6. Test data

`data/employees.csv` is the HR source. Five test identities already
exist in Keycloak (Maria, Nikos, Giorgos, Eleni, Alex).

**Known limitation:** these identities carry development/test history
from earlier work (e.g. Alex has already been moved between
departments and role-changed multiple times; Nikos has been manually
granted `it-admin`). Test cases must state the **actual** starting
state they assume, not an idealized "fresh" state — and where a clean
starting point matters, a test case should establish it explicitly
rather than assume it.

## 7. Defect management

Defects are documented individually under `testing/defects/`
(`BUG-001.md`, etc.). Each record contains: Defect ID, Title,
Severity, Priority, Requirement, Environment, Preconditions, Steps to
Reproduce, Expected Result, Actual Result, Evidence, Root Cause,
Impact, Status.

**Defect lifecycle.** A failed test execution does not automatically
mean the test case itself is wrong. The failure is investigated to
determine whether it is caused by an implementation defect, an
incorrect or incomplete requirement, invalid test data, an
environment/configuration issue, or an issue in the test procedure
itself. When an implementation defect is identified, it is recorded
and linked to the relevant test case and requirement.

The **Root Cause** field records the identified cause once
sufficient investigation has been done — it may be `TBD` or `Under
investigation` before that. The **Impact** field describes the
functional/business effect independently of the technical cause.

Defect status is tracked separately from test execution status: a
failed test may remain linked to an open defect until the defect is
fixed and the test is successfully retested.

**Severity scale:**
- **Critical** — prevents a core system function, or causes a severe
  security/authorization failure.
- **High** — significantly affects an important requirement or
  workflow.
- **Medium** — affects functionality but does not prevent the main
  workflow from operating.
- **Low** — minor functional/usability issue with limited impact.

**Retesting and regression.** After a defect is fixed: the originally
failed test case is executed again (retest) and the result recorded;
related tests are considered for regression, to verify the fix did
not introduce unintended changes elsewhere. The original failed
execution and its evidence are retained — not overwritten — so the
defect's full lifecycle stays traceable.

## 8. Tools

Postman, PowerShell, Keycloak Admin Console, Git/GitHub.

## 9. Entry / Exit criteria

**Entry criteria:**
- Requirements baseline locked (done)
- JML automation and `acme-api` functional (done)

**Exit criteria:**
- Every requirement (REQ-001–REQ-017) has at least one executed test
  case with a recorded result
- No open Critical or High severity defects remain without an
  explicit, documented disposition (fixed, deferred, or accepted)
