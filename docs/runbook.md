# Runbook: troubleshooting the local lab

Each entry lists a symptom, its confirmed cause in this project, and the
fix. Only issues actually observed in this lab are included; the source of
each is noted.

## Diagnosing 401 vs 403

| Code | Meaning | First check |
|------|---------|-------------|
| 401 | The caller was not authenticated | Token missing or expired (access token lifetime is 300 s), token not accepted by introspection, wrong `acme-api` secret |
| 403 | The caller is known but not allowed | Roles and groups of the user vs. the rule of that endpoint |

A 403 is not necessarily a fault: several test cases in
`testing/test-cases.md` expect it. Compare the result with the expected
result of the test case before treating it as a defect.

For a 403, call `/api/whoami` with the same token and compare the roles and
groups it shows with what the endpoint requires.

## Symptoms

### 401 on `/api/whoami`, or introspection returns `active: false`
- **Cause:** the calling client (`acme-api`) is not in the token's `aud`
  claim, so introspection reports the token as inactive. The
  `audience-acme-api` scope must be a default scope of `acme-web`, and its
  audience mapper needs both "Add to access token" and "Add to token
  introspection" turned on.
- **Source:** ADR-0002 (audience addendum).
- **Fix:** check the scope and mapper in Admin Console (Clients ->
  `acme-web` -> Client scopes), then request a **new** token. Tokens issued
  earlier keep their old claims.

### `acme-api` rejects every token after a fresh import
- **Cause:** `realm-export.json` stores client secrets masked, so Keycloak
  generates new secrets on import. The value in your environment is stale.
- **Fix:** copy the current secret from Admin Console (Clients -> `acme-api`
  -> Credentials) into `ACME_API_CLIENT_SECRET` and restart the API. The
  `acme-provisioner` secret goes into `.env` as `KEYCLOAK_CLIENT_SECRET`
  (README steps 3 and 7). Never paste secrets into chats, issues or commits.
  If a secret appears in a log or a screenshot, regenerate it.

### 403 on `/api/it/admin` for `nikos-e002` (TC-023)
- **Cause:** the `it-admin` realm role is never granted automatically
  (REQ-006). Without it the endpoint correctly refuses.
- **Fix:** Users -> `nikos-e002` -> Role mapping -> assign `it-admin`
  (README step 6), then request a new token.

### Admin Console: "We are sorry... please login again"
- **Cause:** cookies are scoped per host, not per port. Two Keycloak
  instances on `localhost:8080` and `localhost:8082` overwrite each other's
  session cookies.
- **Fix:** use a private window, or open one instance via `127.0.0.1`.

### `409 Conflict` when running `provision-users.ps1`
- **Cause:** a username already exists. This happened when usernames were
  derived from the first name alone (BUG-001, closed).
- **Current behaviour:** usernames are `FirstName-EmployeeID` (ADR-0007),
  for example `nikos-e002`. If a 409 appears again, check whether that exact
  username already exists in Keycloak.
- **Source:** `testing/defects/BUG-001.md`, ADR-0007, TC-007.

### Login fails for `nikos`, `maria` or `giorgos`
- **Cause:** those short usernames were replaced by the ADR-0007 form
  (`nikos-e002`, `maria-e001`, `giorgos-e003`).
- **Fix:** use the new usernames in Postman and in the test environment.

### The realm disappeared after `docker compose down`
- **Cause:** `docker-compose.yml` has no named volume, so Keycloak data
  lives inside the container and is removed with it.
- **Fix:** before destroying the container, export the realm (Admin Console
  -> Realm settings -> Action -> Partial export). Note that the export masks
  client secrets. Re-import happens only when the realm does not yet exist.