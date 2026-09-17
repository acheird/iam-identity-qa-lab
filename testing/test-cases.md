# Test Cases — IAM Identity Lifecycle & QA Lab

Each test case expands one test scenario (`test-scenarios.md`) into a
concrete, executable check: preconditions, exact test data, steps,
and expected result. See `test-strategy.md` for the overall approach.

Status starts as "Not yet executed" — execution is a separate,
subsequent step, not assumed here.

---

### TC-001 — New employee gets a Keycloak identity created

- **Scenario:** TS-01
- **Requirement:** REQ-001, REQ-002
- **Preconditions:** An employee with a given `EmployeeID` does not
  yet exist in Keycloak (no user has that value in the `employeeId`
  attribute).
- **Test Data:** A new row added to `data/employees.csv`, e.g.
  `E006,Test,User,IT,Employee,Active,testuser@email.com`.
- **Steps:**
  1. Add the row above to `data/employees.csv`.
  2. Run `.\scripts\provision-users.ps1`.
- **Expected Result:** Output shows `E006` as "NOT FOUND - creating...",
  then "CREATED", with a new Keycloak user ID. The user exists in
  Keycloak Admin Console with matching first/last name and email.
- **Actual Result:** `E006` created (id: `a42b7b9f-277a-4686-8583-cc4bb1aa72e4`),
  added to `department-it`, `employee` role assigned. Confirmed in
  Admin Console: First name `Test`, Last name `User`, email
  `testuser@email.com`.
- **Status:** PASS

---

### TC-002 — Re-running the Joiner for an existing employee does not duplicate

- **Scenario:** TS-02
- **Requirement:** REQ-002
- **Preconditions:** The employee from TC-001 (`E006`) already exists
  in Keycloak.
- **Test Data:** Same CSV row as TC-001, unchanged.
- **Steps:**
  1. Note the Keycloak user ID of `E006` (from TC-001 or the Admin
     Console).
  2. Run `.\scripts\provision-users.ps1` again, with no CSV change.
- **Expected Result:** Output shows `E006` as "FOUND in Keycloak",
  with the **same** user ID as before — no new user created.
- **Actual Result:** `E006` FOUND, id `a42b7b9f-277a-4686-8583-cc4bb1aa72e4`
  — identical to TC-001's created ID. No duplicate created.
- **Status:** PASS

---

### TC-003 — Active employee belongs to the correct department group

- **Scenario:** TS-03
- **Requirement:** REQ-003
- **Preconditions:** None beyond a provisioned, active employee.
- **Test Data:** Maria (E001), CSV `Department=HR`.
- **Steps:**
  1. Keycloak Admin Console → Users → maria → tab "Groups".
- **Expected Result:** Exactly one group is listed: `department-hr`.
  No other department group is present.
- **Status:** Not yet executed

---

### TC-004 — Every active employee holds the employee role

- **Scenario:** TS-04
- **Requirement:** REQ-004
- **Preconditions:** None beyond a provisioned, active employee.
- **Test Data:** Giorgos (E003), CSV `Role=Employee`.
- **Steps:**
  1. Keycloak Admin Console → Users → giorgos → tab "Role mapping".
- **Expected Result:** `employee` is present in the assigned roles.
- **Status:** Not yet executed

---

### TC-005 — Manager holds both employee and manager roles

- **Scenario:** TS-05
- **Requirement:** REQ-005
- **Preconditions:** None beyond a provisioned employee with CSV
  `Role=Manager`.
- **Test Data:** Nikos (E002), CSV `Role=Manager`.
- **Steps:**
  1. Keycloak Admin Console → Users → nikos → tab "Role mapping".
- **Expected Result:** **Both** `employee` and `manager` are present
  — `manager` is not a replacement for `employee`.
- **Status:** Not yet executed

---

### TC-006 — Privileged roles are never assigned automatically

- **Scenario:** TS-06
- **Requirement:** REQ-006
- **Preconditions:** `data/employees.csv` contains no field capable of
  requesting `hr-admin`/`it-admin` (the CSV schema has no such
  column — this is a design-level guarantee, not a runtime choice).
- **Test Data:** All current CSV rows (Maria, Nikos, Giorgos, Eleni,
  Alex).
- **Steps:**
  1. Run `.\scripts\provision-users.ps1` and `.\scripts\update-users.ps1`
     against the current CSV.
  2. For each user, check Role mapping in Admin Console.
- **Expected Result:** No user has `hr-admin` or `it-admin` **as a
  result of this run**, unless it was already present from a prior,
  explicit manual grant (e.g. Nikos's `it-admin`, granted manually
  earlier — not by this script). The scripts must not add or remove
  either role.
- **Status:** Not yet executed

---

### TC-007 — Joiner creates identity, department, and role together

- **Scenario:** TS-07
- **Requirement:** REQ-007
- **Preconditions:** `E007` does not yet exist in Keycloak.
- **Test Data:** New CSV row:
  `E007,Test,Manager,Finance,Manager,Active,testmanager@email.com`
- **Steps:**
  1. Add the row above to `data/employees.csv`.
  2. Run `.\scripts\provision-users.ps1`.
- **Expected Result:** In a single run: identity created, added to
  `department-finance`, and holds **both** `employee` and `manager`
  — all three together, not requiring any follow-up run.
- **Actual Result (original execution):** Creation failed with `409
  Conflict` — the derived username (`test`) collided with `E006`'s,
  created earlier with the same `FirstName`. No identity, group, or
  role was created for `E007`. See **BUG-001**.
- **Actual Result (retest, after changing `E007`'s `FirstName` to a
  unique value — `Manager` — not a fix to the underlying defect):**
  `E007` created (id: `0cc66ddb-9031-4aea-907d-5c223869d68e`), added
  to `department-finance`, roles `employee` + `manager` assigned
  together, in one run.
- **Status:** PASS (retest). BUG-001 remains **Open** — this retest
  used different test data, it did not fix or disprove the
  underlying username-collision defect.

---

### TC-008 — Department change: old group removed, new group added

- **Scenario:** TS-08
- **Requirement:** REQ-008
- **Preconditions:** `E006` exists with `department-it` (from TC-001).
- **Test Data:** Change `E006`'s CSV `Department` from `IT` to
  `Finance` (Role stays `Employee`).
- **Steps:**
  1. Edit the `E006` row in `data/employees.csv`, changing
     `Department` to `Finance`.
  2. Run `.\scripts\update-users.ps1`.
- **Expected Result:** Output shows a department change detected for
  `E006`. Afterward, `E006`'s groups contain **only**
  `department-finance` — `department-it` is no longer present.
- **Actual Result:** Output showed the department change detected
  and applied for `E006` exactly as expected — `department-it`
  removed, `department-finance` added.
- **Status:** PASS. (Note: this same execution, run against the full
  CSV as always, also touched an unrelated `Terminated` employee
  already present in the file and surfaced two separate defects —
  BUG-002 and BUG-003. Those are independent findings, not part of
  TC-008's own pass/fail — see the defect files for detail, and the
  planned new test case covering Mover behavior for terminated
  employees specifically.)

---

### TC-009 — Re-running the Mover with no change makes no further change

- **Scenario:** TS-09
- **Requirement:** REQ-008
- **Preconditions:** `E006` already has `department-finance` (from
  TC-008).
- **Test Data:** Same CSV row as after TC-008, unchanged.
- **Steps:**
  1. Run `.\scripts\update-users.ps1` again, with no CSV change.
- **Expected Result:** Output shows `E006`'s department as "already
  correct" — no remove/add action taken.
- **Actual Result:** `E006` shows "department already correct
  (department-finance)" — no further action, as expected. (Also
  confirms BUG-002 is stable/reproducible: `E004` again shows
  "already correct (department-sales)", the same incorrect state
  from the previous run — not a one-off.)
- **Status:** PASS

---

### TC-010 — Role change: Employee → Manager adds manager, keeps employee

- **Scenario:** TS-10
- **Requirement:** REQ-009
- **Preconditions:** `E006` currently holds only `employee` (from
  TC-001; department is `Finance` per TC-008, which is independent
  and irrelevant here).
- **Test Data:** Change `E006`'s CSV `Role` from `Employee` to
  `Manager`.
- **Steps:**
  1. Edit the `E006` row, changing `Role` to `Manager`.
  2. Run `.\scripts\update-users.ps1`.
- **Expected Result:** Output shows a role change detected
  (Employee → Manager). Afterward, `E006` holds **both** `employee`
  and `manager`.
- **Actual Result:** Output showed "role change detected - Employee
  -> Manager", "manager role added". Department (`department-finance`)
  correctly unaffected.
- **Status:** PASS

---

### TC-011 — Role change: Manager → Employee removes manager, keeps employee

- **Scenario:** TS-11
- **Requirement:** REQ-009
- **Preconditions:** `E006` currently holds both `employee` and
  `manager` (from TC-010).
- **Test Data:** Change `E006`'s CSV `Role` from `Manager` back to
  `Employee`.
- **Steps:**
  1. Edit the `E006` row, changing `Role` back to `Employee`.
  2. Run `.\scripts\update-users.ps1`.
- **Expected Result:** Output shows a role change detected
  (Manager → Employee). Afterward, `E006` holds **only** `employee`
  — `manager` is no longer present.
- **Actual Result:** Output showed "role change detected - Manager
  -> Employee", "manager role removed, employee retained".
- **Status:** PASS

---

### TC-012 — Combined department and role change in the same run

- **Scenario:** TS-12
- **Requirement:** REQ-008, REQ-009
- **Preconditions:** `E007` currently has `department-finance` and
  holds `employee` + `manager` (from TC-007).
- **Test Data:** Change `E007`'s CSV `Department` from `Finance` to
  `IT`, **and** `Role` from `Manager` to `Employee`, in the same CSV
  edit.
- **Steps:**
  1. Edit the `E007` row, changing both `Department` to `IT` and
     `Role` to `Employee`.
  2. Run `.\scripts\update-users.ps1` **once**.
- **Expected Result:** Both changes are applied in the same run:
  `E007` ends with **only** `department-it` (not `department-finance`)
  and **only** `employee` (not `manager`) — no leftover state from
  either previous dimension.
- **Actual Result:** Output showed both changes detected and applied
  together in one run: department moved `department-finance` →
  `department-it`; role changed Manager → Employee, `manager`
  removed, `employee` retained.
- **Status:** PASS

---

### TC-013 — Terminated employee's account is disabled

- **Scenario:** TS-13
- **Requirement:** REQ-010
- **Preconditions:** `E008` exists in Keycloak, `Active`,
  `department-sales`, `employee`. (Create via Joiner first if not
  already present:
  `E008,Test,Leaver,Sales,Employee,Active,testleaver@email.com`.)
- **Test Data:** Change `E008`'s CSV `Status` from `Active` to
  `Terminated`.
- **Steps:**
  1. Edit the `E008` row, changing `Status` to `Terminated`.
  2. Run `.\scripts\deprovision-users.ps1`.
- **Expected Result:** Output shows `E008`: "account disabled". In
  Admin Console, `E008`'s "Enabled" toggle is off.
- **Actual Result:** Output showed "account disabled". Confirmed in
  Admin Console: "Enabled" = false.
- **Status:** PASS

---

### TC-014 — Terminated employee's group and role access is removed

- **Scenario:** TS-14
- **Requirement:** REQ-011
- **Preconditions:** Same execution as TC-013 — this checks a
  different result of the **same** `deprovision-users.ps1` run, not a
  separate execution.
- **Test Data:** Same as TC-013.
- **Steps:** (already performed in TC-013)
  1. In Admin Console, check `E008`'s "Groups" tab.
  2. Check `E008`'s "Role mapping" tab.
- **Expected Result:** No groups present (`department-sales` removed).
  No business roles present (`employee` removed) — only Keycloak's
  own default roles remain untouched, per the project's model.
- **Actual Result:** Groups empty. Role mapping shows only
  `default-roles-acme` — `employee` correctly removed.
- **Status:** PASS

---

### TC-015 — Terminated employee's already-issued token is no longer active

- **Scenario:** TS-15
- **Requirement:** REQ-012
- **Preconditions:** `E008` is `Active` (before termination), with a
  password set in Keycloak, `department-sales`, `employee`. This is
  the one case in this batch that must be run **before** TC-013 puts
  `E008` into `Terminated` state, since it needs a token issued while
  still active.
- **Test Data:** `E008`'s own login credentials.
- **Steps:**
  1. Log in as `E008` via Postman (`client_id=acme-web`,
     `scope=openid`), obtain `access_token`.
  2. Introspect this token (`client_id=acme-api` + secret) — confirm
     baseline `active: true`.
  3. Proceed with TC-013 (change `Status` to `Terminated`, run
     `deprovision-users.ps1`), done promptly after step 2 so the
     token has not naturally expired.
  4. Introspect the **same** token again (not a new one).
- **Expected Result:** Step 2 returns `active: true`. Step 4 returns
  `active: false`, and the elapsed time between steps 3 and 4 is
  small enough (well under the token's lifetime) to rule out natural
  expiry as the explanation — matching the empirical result already
  established in `architecture.md` Section 10.
- **Actual Result:** Step 2 (baseline, before termination):
  `active: true`, with correct claims (`username: leaver`,
  `groups: [department-sales]`, `employee` role). Step 4 (same token,
  after `deprovision-users.ps1`): `active: false`. Elapsed time
  between termination and recheck was well under a minute.
- **Status:** PASS

---

### TC-016 — Re-running the Leaver for an already-terminated employee does not error

- **Scenario:** TS-16
- **Requirement:** REQ-010, REQ-011, REQ-012
- **Preconditions:** `E008` is already `Terminated` and fully
  deprovisioned (from TC-013/014/015).
- **Test Data:** Same CSV row as after TC-013, unchanged.
- **Steps:**
  1. Run `.\scripts\deprovision-users.ps1` again, with no CSV change.
- **Expected Result:** `E008` is processed without error or
  exception — the script completes successfully even though the
  account is already disabled and no department group or business
  roles remain. No access is granted or restored as a result of this
  re-run.
- **Actual Result:** `E008` (and `E004`, also still `Terminated`)
  processed again with no error or exception. Groups empty, no
  business roles to remove, sessions revoked call completed — no
  access restored to either.
- **Status:** PASS

---

**Execution order note:** test case IDs follow scenario order
(TS-13→16) for traceability, not execution order. TC-015's steps 1–2
(obtain and baseline-check a token while `E008` is still `Active`)
must run **before** TC-013/014 (which terminate `E008`); its step 4
(re-introspect the same token) runs **after**. The actual execution
sequence is: TC-015 (steps 1–2) → TC-013 → TC-014 → TC-015 (step 4)
→ TC-016.

---

### TC-017 — IT department user can access `/api/it/data`

- **Scenario:** TS-17
- **Requirement:** REQ-013
- **Preconditions:** Nikos (E002) has `department-it`.
- **Test Data:** Nikos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/it/data`, with Nikos's token.
- **Expected Result:** `200`, with IT data in the response body.
- **Actual Result:** `200`, `{"message": "Welcome to IT data",
  "department": "IT"}`.
- **Status:** PASS

---

### TC-018 — Non-IT user is denied `/api/it/data`

- **Scenario:** TS-17
- **Requirement:** REQ-013
- **Preconditions:** Giorgos (E003) has `department-finance`, not
  `department-it`.
- **Test Data:** Giorgos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/it/data`, with Giorgos's token.
- **Expected Result:** `403 Forbidden`.
- **Actual Result:** `403 Forbidden`.
- **Status:** PASS

---

### TC-019 — Finance department user can access `/api/finance/data`

- **Scenario:** TS-18
- **Requirement:** REQ-014
- **Preconditions:** Giorgos (E003) has `department-finance`.
- **Test Data:** Giorgos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/finance/data`, with Giorgos's
     token.
- **Expected Result:** `200`, with Finance data in the response body.
- **Actual Result:** `200`, `{"message": "Welcome to Finance data",
  "department": "Finance"}`.
- **Status:** PASS

---

### TC-020 — Non-Finance user is denied `/api/finance/data`

- **Scenario:** TS-18
- **Requirement:** REQ-014
- **Preconditions:** Nikos (E002) has `department-it`, not
  `department-finance`.
- **Test Data:** Nikos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/finance/data`, with Nikos's token.
- **Expected Result:** `403 Forbidden`.
- **Actual Result:** `403 Forbidden`.
- **Status:** PASS

---

### TC-021 — Manager (any department) can access `/api/manager/dashboard`

- **Scenario:** TS-19
- **Requirement:** REQ-015
- **Preconditions:** Nikos (E002) holds `manager` (department is
  `department-it`, deliberately irrelevant here — this checks the
  role dimension independently).
- **Test Data:** Nikos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/manager/dashboard`, with Nikos's
     token.
- **Expected Result:** `200`.
- **Actual Result:** `200`, `{"message": "Welcome to the manager
  dashboard"}`.
- **Status:** PASS

---

### TC-022 — Non-manager is denied `/api/manager/dashboard`

- **Scenario:** TS-19
- **Requirement:** REQ-015
- **Preconditions:** Maria (E001) holds `employee` only, not
  `manager`.
- **Test Data:** Maria's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/manager/dashboard`, with Maria's
     token.
- **Expected Result:** `403 Forbidden`.
- **Actual Result:** `403 Forbidden`.
- **Status:** PASS

---

### TC-023 — User with both `department-it` and `it-admin` can access `/api/it/admin`

- **Scenario:** TS-20
- **Requirement:** REQ-016
- **Preconditions:** Nikos (E002) has **both** `department-it` and
  `it-admin` (the latter granted manually — REQ-006).
- **Test Data:** Nikos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/it/admin`, with Nikos's token.
- **Expected Result:** `200`.
- **Actual Result:** `200`, `{"message": "Welcome to IT
  administration"}`.
- **Status:** PASS

---

### TC-024 — User missing group or role is denied `/api/it/admin`

- **Scenario:** TS-20
- **Requirement:** REQ-016
- **Preconditions:** Giorgos (E003) has neither `department-it` nor
  `it-admin`.
- **Test Data:** Giorgos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/it/admin`, with Giorgos's token.
- **Expected Result:** `403 Forbidden`.
- **Actual Result:** `403 Forbidden`.
- **Status:** PASS

---

### TC-025 — Valid token is accepted by `/api/whoami`

- **Scenario:** TS-21
- **Requirement:** REQ-012
- **Preconditions:** Any active employee with a valid, unexpired
  token.
- **Test Data:** Nikos's access token.
- **Steps:**
  1. `GET http://localhost:8081/api/whoami`, with Nikos's token.
- **Expected Result:** `200` — the protected endpoint accepts the
  valid token and returns the expected identity information
  (`username`, `groups`; the response also happens to include
  `active: true`, but the core assertion here is that the endpoint
  **accepted** the token, not an independent introspection proof —
  that belongs to TC-015/REQ-012).
- **Status:** Not yet executed

---

### TC-026 — Missing or invalid token is rejected

- **Scenario:** TS-22
- **Requirement:** REQ-012
- **Preconditions:** None.
- **Test Data:** No `Authorization` header; separately, a clearly
  invalid token string.
- **Steps:**
  1. `GET http://localhost:8081/api/whoami`, with no `Authorization`
     header.
  2. Repeat, with `Authorization: Bearer not-a-real-token`.
- **Expected Result:** Both requests return `401 Unauthorized`.
- **Status:** Not yet executed

---

### TC-027 — `acme-provisioner` holds only its required permissions

- **Scenario:** TS-23
- **Requirement:** REQ-017
- **Preconditions:** None.
- **Test Data:** `acme-provisioner`'s client credentials.
- **Steps:**
  1. Admin Console → Clients → `acme-provisioner` → tab "Service
     accounts roles" — this is the primary, authoritative source of
     what permissions are actually granted (not what claims happen
     to appear in a token, which depends on separate mapper
     configuration).
  2. *(Optional)* Obtain a token via `grant_type=client_credentials`
     to confirm the service account can still authenticate — this
     only checks that it works, not what it's permitted to do.
- **Expected Result:** The assigned `realm-management` roles listed
  in step 1 are exactly `manage-users` and `view-realm` — no broader
  permission (e.g. `manage-realm`, `manage-clients`) is present. This
  test does **not** assert that `manage-users` cannot technically
  perform more than the scripts use (see ADR-0005's documented
  residual risk) — only that no additional, unrelated permission has
  been granted.
- **Status:** Not yet executed
