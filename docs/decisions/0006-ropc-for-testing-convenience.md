# ADR-0006: Direct Access Grants (ROPC) enabled on `acme-web` for testing only

## Status
Accepted — explicitly not a production recommendation

## Context
Verifying the IAM model (Section 1.2 verification, and later manual
testing) requires obtaining tokens for test users without building a
real browser-based frontend for `acme-web`. Keycloak's Direct Access
Grants (the OAuth2 Resource Owner Password Credentials — ROPC — flow)
allows requesting a token directly with a username and password via
tools like Postman.

## Decision
Direct Access Grants (ROPC) are enabled on `acme-web` solely for
testing convenience via Postman, avoiding the need to build a
browser-based frontend for this lab.

## Consequences
- **Benefit:** allows verifying the IAM model end-to-end (login →
  token → claims) without building a real frontend, which is out of
  scope for this project.
- **Trade-off / risk:** ROPC is discouraged in modern OAuth 2.0
  practice and is not included in OAuth 2.1, because it requires the
  client to handle the user's credentials directly and prevents the
  authorization server from providing some of the protections
  available through browser-based authorization flows. It also has
  important limitations around MFA and external identity-provider
  scenarios.
- **Scope of acceptance:** this configuration is acceptable for the
  controlled lab environment and should not be considered a
  production recommendation. A hardened deployment would use an
  appropriate Authorization Code-based flow and disable Direct Access
  Grants.
