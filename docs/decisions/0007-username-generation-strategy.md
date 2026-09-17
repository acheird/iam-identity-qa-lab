# ADR-0007: Username generation uses FirstName + EmployeeID, not FirstName alone

## Status
Accepted

## Context
BUG-001 (username collision) showed that deriving a Keycloak
username from `$employee.FirstName.ToLower()` alone does not
guarantee uniqueness — two employees sharing a first name collide,
and Joiner provisioning fails with a `409 Conflict` for the second
one. This is a realistic failure mode, not a purely theoretical edge
case: duplicate first names are common in any real organization.

`EmployeeID` is already the project's authoritative uniqueness anchor
for identity itself (REQ-002) — the question here is a separate,
narrower one: how the technical login username should be derived so
that, as long as `EmployeeID` remains unique (which REQ-002 already
guarantees), the username derived from it stays unique too, without
introducing a second, independent uniqueness mechanism.

## Decision
Generate the username as `FirstName-EmployeeID` (lowercased), e.g.
`E006` with `FirstName=Test` becomes `test-e006`. This is
deterministic — the same employee always produces the same username,
regardless of what else exists in Keycloak at the time — and
unique, since it inherits uniqueness directly from `EmployeeID`
rather than introducing a second, independent uniqueness mechanism.

## Alternatives considered

| Option | Uniqueness | Deterministic | Complexity | Why rejected |
|---|---|---|---|---|
| `FirstName.LastInitial` (e.g. `test.u`) | No | Yes | Low | Narrows the collision window but doesn't close it — two employees with the same first name **and** last initial still collide. |
| `FirstName.LastName` (e.g. `test.user`) | No | Yes | Low | More natural-looking, but two employees can still share a full name; also creates an implicit coupling between a personal attribute (surname) and a technical identifier — a later surname change would raise the question of whether the username should change too, which this project does not want the username generation to depend on. |
| Collision detection + numeric fallback (e.g. `test`, then `test2`, `test3`, ...) | Yes, if implemented correctly | **No** | Medium | Not rejected for failing to ensure uniqueness — it can. Rejected because it makes username generation state-dependent: which suffix an employee gets depends on provisioning order and on who else exists at that moment, not on anything about the employee. Also introduces real implementation concerns (lookup-before-create, concurrent provisioning, retry count) disproportionate to this lab's scope. |
| `FirstName-EmployeeID` (chosen) | Yes | Yes | Very low | — |

## Consequences
- As long as `EmployeeID` stays unique — already guaranteed by
  REQ-002 — the derived username is unique too, with no additional
  lookup or fallback logic required at creation time.
- The username is less "natural-looking" than a plain
  first-name-based one — this is an accepted trade-off, not an
  oversight: the username is a technical/login identifier, not the
  employee's display name (which is already stored separately as
  First/Last name on the user record).
- REQ-002 itself is unchanged — it already anchors identity
  uniqueness to `EmployeeID`, not to username or name. This decision
  is an implementation detail of *how* the username is derived, not
  a new business requirement.
