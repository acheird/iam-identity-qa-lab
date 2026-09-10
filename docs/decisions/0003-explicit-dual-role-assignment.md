# ADR-0003: Explicit dual role assignment instead of composite roles

## Status
Accepted

## Context
A Manager must hold both `employee` and `manager` (REQ-004, REQ-005).
Keycloak supports composite roles, where assigning `manager` could
automatically imply `employee`. The alternative is assigning both
roles explicitly and independently to the same user.

## Decision
Assign `employee` and `manager` as two separate, explicit realm role
assignments on the user. `manager` is never made composite over
`employee`.

## Consequences
- **Benefit:** keeps REQ-009 role downgrade unambiguous. An explicitly
  assigned `employee` role survives removal of `manager`, whereas an
  implied (composite-inherited) role would disappear along with it —
  composite roles would make the Manager→Employee downgrade scenario
  in REQ-009 impossible to satisfy correctly. It also keeps a user's
  actual role assignments fully visible in the Admin Console/API,
  rather than requiring knowledge of composite resolution to know
  what a user "really" has.
- **Trade-off:** more explicit assignments needed per user compared to
  a composite hierarchy; does not scale as gracefully to many role
  levels.
- **Alternative considered:** composite roles — the same pattern OIM
  uses for hierarchical Business Roles. Rejected here specifically
  because the project has only two levels, so the
  administrative-overhead benefit of composites doesn't outweigh the
  testability cost.
