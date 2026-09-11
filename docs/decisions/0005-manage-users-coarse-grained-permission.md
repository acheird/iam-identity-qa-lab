# ADR-0005: `acme-provisioner` uses the built-in `manage-users` and `view-realm` roles

## Status
Accepted

## Context
`acme-provisioner` (ADR-0004) needs specific Keycloak administrative
permissions: find/read users, create/update users, manage group and
role membership, and disable accounts — see the operations matrix in
`architecture.md` Section 8. Keycloak's default `realm-management`
client roles are coarse-grained; there is no built-in role that grants
exactly this set without also granting more.

## Decision
Grant `acme-provisioner`'s service account the built-in
`realm-management` roles `manage-users` **and `view-realm`**. This is
accepted as least privilege *within the constraints of Keycloak's
built-in administrative roles* — not true operation-level least
privilege.

**Empirical finding:** `manage-users` alone was initially assumed
sufficient, based on Keycloak documentation, for every operation in
the matrix below. In practice, looking up realm role definitions
(required before assigning a role — Keycloak's role-mappings endpoint
needs full role objects, not names) returned `403 Forbidden` under
`manage-users` alone. `view-realm` was added and resolved it. This is
kept here deliberately as a real example of verifying permissions
empirically rather than trusting documentation alone — the same
principle applied throughout this project (e.g. REQ-012's session
revocation mechanism).

## Consequences
- **Benefit:** `manage-users` + `view-realm` is the minimal built-in
  role combination that covers every operation the provisioning
  scripts actually need.
- **Trade-off / residual risk:** the service account technically has
  delete-user capability it will never use, since the Leaver
  requirement (REQ-010) is deactivation, not identity deletion. This
  is enforced by code discipline — no script calls the delete
  endpoint — rather than by the Keycloak permission model itself. This
  is a real, explicitly acknowledged gap relative to true least
  privilege, not a silent omission. It is reflected in the operations
  matrix (`architecture.md` Section 8) as "Delete user: not enforceable
  with a built-in role".
- **Alternative considered:** Keycloak's Fine-Grained Admin Permissions,
  which would allow excluding delete explicitly at the permission
  level. Rejected for this lab: it would add meaningful IAM
  configuration complexity without a proportionate benefit at this
  project's scope.
