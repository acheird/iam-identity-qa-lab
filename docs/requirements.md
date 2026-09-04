# Requirements — IAM Identity Lifecycle & QA Lab

Each requirement is written to be directly testable (positive, negative, and
edge cases will be derived from these in `testing/test-cases.md`).

## 1. Identity Creation

**REQ-001 — Employee Identity Creation**
When a new employee record is added to the HR source with status `Active`,
a corresponding IAM identity must be provisioned.

**REQ-002 — Unique Identity**
Each Employee ID must map to exactly one IAM identity. Re-running
provisioning for an existing Employee ID must not create a duplicate account.

## 2. Department Assignment

**REQ-003 — Department Group Assignment**
An active employee must belong to the IAM group corresponding to their HR
department, and to no other department group (e.g. `Department = IT` →
member of `department-it` only).

## 3. Role Assignment

**REQ-004 — Employee Role**
Every active employee must hold the `employee` role.

**REQ-005 — Manager Role**
An employee whose HR record has `Role = Manager` must additionally hold the
`manager` role.

**REQ-006 — Administrator Roles**
The `hr-admin` and `it-admin` roles must never be assigned automatically
from the HR feed. They may only be granted through a separate, explicit
IAM Administrator action. A standard employee record must never result in
administrator access.

## 4. Joiner

**REQ-007 — Joiner Provisioning**
When an employee becomes `Active`, the system must, in this order: create
the identity → assign the correct department group → assign the correct
role(s) → grant access to the corresponding application(s).

## 5. Mover

**REQ-008 — Department Change**
When an employee's department changes, the previous department group must
be removed and the new department group added. At no point should the
employee hold more than one department group.

**REQ-009 — Role Change**
When an employee's role changes (e.g. `Employee → Manager` or
`Manager → Employee`), the corresponding role membership must be updated
the same way: the old role removed, the new role added. This is
independent of, and must be tested separately from, REQ-008 — a department
change and a role change can happen together or separately.

> **Edge case to test, not a separate requirement:** a single HR update can
> change department and role at the same time (e.g. `IT/Employee →
> Finance/Manager`). REQ-008 and REQ-009 both apply to this case
> independently; after such a change the employee must end up with exactly
> `department-finance` + `manager`, with no leftover `department-it` or
> `employee` membership from before.

## 6. Leaver

**REQ-010 — Account Deactivation**
When an employee's status becomes `Terminated`, the IAM account must be
disabled and the user must no longer be able to log in.

**REQ-011 — Access Revocation**
After termination, all application access previously granted through group
and role membership must be revoked.

**REQ-012 — Active Session Revocation**
Disabling an account must not be treated as sufficient on its own: a
terminated employee must not be able to continue using an already-open
session to access any application after termination. How this is achieved
is an implementation decision to be made at the Keycloak design stage, not
part of this requirement.

## 7. Authorization

**REQ-013 — IT Access**
Employees in `department-it` may access the IT Portal. Employees outside
`department-it` must not have IT administrative functionality.

**REQ-014 — Finance Access**
Employees in `department-finance` may access the Finance Portal.

**REQ-015 — Manager Access**
Only users holding the `manager` role may access manager-only
functionality. Standard employees must not.

**REQ-016 — Administrator Access**
Administrator functionality must be available only to users explicitly
holding `hr-admin` or `it-admin`.

## 8. Security

**REQ-017 — Least Privilege**
At any point in time, an employee must hold exactly the group and role
memberships required by their current department and role — no more, no
less, and no leftover memberships from a previous department or role.

---

### Traceability note
REQ-008/REQ-009 (Mover) and REQ-010–REQ-012 (Leaver) are the highest-value
requirements for demonstrating QA depth: they are where positive tests are
easy but negative/edge cases (leftover group after a move, session still
valid after termination, double department change) are where real defects
tend to hide.
