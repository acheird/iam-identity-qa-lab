# Business Scenario — Acme Technologies

## Company Context

Acme Technologies is a fictional company (~100 employees) used as the basis for this
IAM Identity Lifecycle & QA Lab. The company relies on a central Identity & Access
Management system to control which corporate applications each employee can use.

## Departments

- IT
- HR
- Finance
- Sales

## Access Types

- Employee
- Manager
- Administrator

## HR Source Data

The company's HR system exports a simple employee feed, e.g. `employees.csv`:

| Employee ID | Name               | Department | Role     | Status |
|-------------|--------------------|------------|----------|--------|
| E001        | Maria Papadopoulou | HR         | Employee | Active |
| E002        | Nikos Georgiou     | IT         | Manager  | Active |
| E003        | Giorgos Antoniou   | Finance    | Employee | Active |
| E004        | Eleni Nikolaou     | Sales      | Employee | Active |

The IAM system consumes this feed to decide who gets an account, which group(s)
they belong to, what permissions they hold, and what changes when their
department, role, or status changes.

## Applications (conceptual)

- HR Portal
- Finance Portal
- IT Portal

These are not built as real applications. Access to them is represented and
verified entirely at the IAM/authorization layer (Keycloak groups, roles, and
clients) — this is intentional, to keep scope small while still allowing
real authorization testing.

## Actors

- **HR Administrator** — creates/updates employee records in the HR source.
- **Employee** — uses the application(s) they have access to.
- **Manager** — has Employee-level access plus manager-only functionality.
- **IAM Administrator** — manages identities, groups, roles, and access policies.

## Access Model

**Groups** (department membership):
`department-it`, `department-hr`, `department-finance`, `department-sales`

**Roles** (function/level):
`employee`, `manager`, `hr-admin`, `it-admin`

Example:
```
Nikos                          Maria
├── department-it              ├── department-hr
├── employee                   └── employee
└── manager
```

Note: a Manager always holds `employee` **and** `manager` — `manager` is
additive, never a replacement for the baseline `employee` role. This
matches REQ-004/REQ-005 and matters directly for REQ-009 (a role change
from Employee → Manager adds `manager` without removing `employee`; the
reverse removes `manager` while keeping `employee`).

## Business Objective

Automate and verify employee identity lifecycle management so that each
employee holds **only** the access required by their current department and
role (least privilege), and that access is removed as soon as it is no
longer required — across the full Joiner → Mover → Leaver lifecycle.

## Scope

**In scope:** Keycloak (users, groups, roles, clients), Joiner/Mover/Leaver
automation via scripts, manual test design and execution, API testing via
Postman, defect reporting, regression testing, a small automated test suite,
and CI via GitHub Actions.

**Out of scope:** Kubernetes, Kafka, ELK, Vault, real front-end applications,
cloud hosting. This is deliberately a small, complete project rather than a
large, partially-finished one.
