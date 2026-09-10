# ADR-0001: Model access as two independent dimensions, not combined roles

## Status
Accepted

## Context
Access could be modeled either as combined, per-department-per-level
roles (e.g. `it-manager`, `finance-employee`), or as two independent
dimensions: a department **Group** and a business **Role**. This
affects how department changes (REQ-008) and role changes (REQ-009)
are represented and tested.

## Decision
Model department and business role as two independent dimensions —
Keycloak Groups (`department-it`, `department-hr`, ...) and Realm
Roles (`employee`, `manager`, ...) — assigned and changed
independently of one another. See `architecture.md` Sections 4–5 for
the resulting model.

## Consequences
- **Benefit:** keeps department changes and role changes independently
  traceable and testable (REQ-008/REQ-009). Scales additively
  (N departments + M levels) rather than multiplicatively (N×M roles)
  as the organization grows.
- **Trade-off:** authorization logic must combine two dimensions at
  evaluation time, rather than reading one self-explanatory role name.
- **Alternative considered:** combined per-department-per-level roles.
  Rejected due to role explosion at scale — this is also the same
  orthogonal pattern One Identity Manager uses (separate Org
  structure vs. Business Role objects) for the same reason.
