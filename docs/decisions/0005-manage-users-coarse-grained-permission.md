# ADR-0005: `acme-provisioner` uses the built-in `manage-users` role

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
`realm-management` role `manage-users`. This is accepted as least
privilege *within the constraints of Keycloak's built-in
administrative roles* — not true operation-level least privilege.

## Consequences
- **Benefit:** `manage-users` is the minimal built-in role that covers
  every operation the provisioning scripts actually need.
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
