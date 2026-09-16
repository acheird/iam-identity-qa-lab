# Test Scenarios — IAM Identity Lifecycle & QA Lab

A test scenario is a short, high-level description of *what* to
verify, derived directly from a requirement — not yet the exact
preconditions, steps, and test data (that is `test-cases.md`, built
from these). See `test-strategy.md` for the overall approach.

Each scenario is tagged with its primary requirement.

## Identity Creation (REQ-001, REQ-002)

- **TS-01** — A new `Active` employee in the CSV results in a
  corresponding Keycloak identity being created.
- **TS-02** — Re-running the Joiner for an already-existing
  `EmployeeID` does not create a duplicate identity.

## Department Assignment (REQ-003)

- **TS-03** — An active employee belongs to the department group
  matching their CSV `Department`, and does not retain an old
  department group.

## Role Assignment (REQ-004, REQ-005, REQ-006)

- **TS-04** — Every active employee holds the `employee` role.
- **TS-05** — An employee with CSV `Role=Manager` holds both
  `employee` and `manager` (additive, not a replacement).
- **TS-06** — Privileged roles (`hr-admin`, `it-admin`) are never
  assigned automatically by the Joiner or Mover, regardless of CSV
  content.

## Joiner (REQ-007)

- **TS-07** — A brand-new employee ends up with identity, correct
  department, and correct role(s) after a single Joiner run.

## Mover — Department (REQ-008)

- **TS-08** — Changing an employee's `Department` in the CSV results
  in the old department group being removed and the new one added,
  with no leftover old group.
- **TS-09** — Running the Mover twice with no CSV change makes no
  further change (idempotency).

## Mover — Role (REQ-009)

- **TS-10** — Changing `Role` from Employee to Manager adds
  `manager`, keeps `employee`.
- **TS-11** — Changing `Role` from Manager to Employee removes
  `manager`, keeps `employee`.
- **TS-12** — A combined department **and** role change in the same
  CSV update is applied correctly for both dimensions in the same run.

## Leaver (REQ-010, REQ-011, REQ-012)

- **TS-13** — A `Terminated` employee's Keycloak account is disabled.
- **TS-14** — A `Terminated` employee's department group and business
  roles are removed.
- **TS-15** — A `Terminated` employee's already-issued access token
  is no longer reported active (via introspection) after Leaver
  processing.
- **TS-16** — Running the Leaver again for an already-terminated
  employee does not error.

## Authorization (REQ-013–REQ-016)

- **TS-17** — A `department-it` user can access `/api/it/data`; a
  user from a different department cannot.
- **TS-18** — A `department-finance` user can access
  `/api/finance/data`; a user from a different department cannot.
- **TS-19** — A `manager` (in any department) can access
  `/api/manager/dashboard`; a non-manager cannot.
- **TS-20** — A user with both `department-it` and `it-admin` can
  access `/api/it/admin`; a user missing either one cannot.

## Session Validity (REQ-012 baseline)

- **TS-21** — A valid, active token is accepted by `/api/whoami`.
- **TS-22** — A request with no token, or an inactive/invalid token,
  is rejected (401) by every protected endpoint.

## Least Privilege (REQ-017)

- **TS-23** — The `acme-provisioner` service account has only the
  Keycloak permissions required for its provisioning responsibilities,
  and provisioning never depends on a human administrator's personal
  credentials. (The corresponding test case records exactly which
  permissions it holds today, and documents `manage-users`'
  coarse-grained residual risk per ADR-0005 — it does not assert that
  today's specific role names are themselves the requirement.)
