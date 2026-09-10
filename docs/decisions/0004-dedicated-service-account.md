# ADR-0004: Dedicated service account for provisioning automation

## Status
Accepted

## Context
The JML provisioning scripts (`provision-users.ps1`, `update-users.ps1`,
`deprovision-users.ps1`) need to call the Keycloak Admin REST API.
They could authenticate using a personal administrator account, or a
dedicated, purpose-built identity.

## Decision
JML provisioning scripts authenticate to the Keycloak Admin REST API
via a dedicated service account client (`acme-provisioner`), using the
OAuth2 Client Credentials grant, never a personal administrator
account.

## Consequences
- **Benefit:** least privilege applies to automation and integration
  accounts, not only end users (the same principle behind REQ-017).
  Automation does not depend on, or require, a personal administrator
  identity, and holds only the specific administrative permissions it
  needs — the same role a connector account plays against a target
  system in a real IGA deployment (e.g. OIM). It also removes
  dependence on a specific person's employment/account status, and
  gives clean accountability in logs (`acme-provisioner created user
  X`, not an ambiguous personal admin action).
- **Trade-off:** more setup than reusing an existing admin account;
  requires deliberately scoping the service account's permissions
  rather than granting broad access by default (see ADR-0005).
- **Secret handling:** the client secret is never committed to the
  repository. Locally it is read from an environment variable
  (`KEYCLOAK_CLIENT_SECRET`); in CI (GitHub Actions, once built) it
  will come from GitHub Actions Secrets. Credentials are
  configuration/secrets, not source code.
