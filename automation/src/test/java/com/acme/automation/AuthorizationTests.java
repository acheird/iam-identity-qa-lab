package com.acme.automation;

import io.restassured.response.Response;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;

public class AuthorizationTests {

    // Set once, in @BeforeAll, then reused by every @Test below -
    // same role as the "Login - Nikos" / "Login - Giorgos" requests
    // in the Postman collection.
    private static String nikosToken;
    private static String giorgosToken;
    private static String mariaToken;

    @BeforeAll
    static void loginAsNikos() {
        // Read from an environment variable, same principle as
        // ACME_API_CLIENT_SECRET for acme-api — never hardcode a
        // real credential in a .java file, since that file is
        // committed to git.
        String password = System.getenv("NIKOS_PASSWORD");

        Response response = given()
                .contentType("application/x-www-form-urlencoded")
                .formParam("grant_type", "password")
                .formParam("client_id", "acme-web")
                .formParam("username", "nikos")
                .formParam("password", password)
                .formParam("scope", "openid")
                .when()
                .post("http://localhost:8080/realms/acme/protocol/openid-connect/token");

        nikosToken = response.jsonPath().getString("access_token");
    }

    @BeforeAll
    static void loginAsGiorgos() {
        String password = System.getenv("GIORGOS_PASSWORD");

        Response response = given()
                .contentType("application/x-www-form-urlencoded")
                .formParam("grant_type", "password")
                .formParam("client_id", "acme-web")
                .formParam("username", "giorgos")
                .formParam("password", password)
                .formParam("scope", "openid")
                .when()
                .post("http://localhost:8080/realms/acme/protocol/openid-connect/token");

        giorgosToken = response.jsonPath().getString("access_token");
    }

    @BeforeAll
    static void loginAsMaria() {
        String password = System.getenv("MARIA_PASSWORD");

        Response response = given()
                .contentType("application/x-www-form-urlencoded")
                .formParam("grant_type", "password")
                .formParam("client_id", "acme-web")
                .formParam("username", "maria")
                .formParam("password", password)
                .formParam("scope", "openid")
                .when()
                .post("http://localhost:8080/realms/acme/protocol/openid-connect/token");

        mariaToken = response.jsonPath().getString("access_token");
    }

    // TC-017 / REQ-013: an IT department user must be able to
    // access IT data.
    @Test
    void itDataAllowsItUser() {
        given()
                .header("Authorization", "Bearer " + nikosToken)
                .when()
                .get("http://localhost:8081/api/it/data")
                .then()
                .statusCode(200)
                .body("department", equalTo("IT"));
    }

    // TC-018 / REQ-013: a non-IT department user must be denied.
    @Test
    void itDataDeniesNonItUser() {
        given()
                .header("Authorization", "Bearer " + giorgosToken)
                .when()
                .get("http://localhost:8081/api/it/data")
                .then()
                .statusCode(403);
    }

    // TC-019 / REQ-014: a Finance department user must be able to
    // access Finance data.
    @Test
    void financeDataAllowsFinanceUser() {
        given()
                .header("Authorization", "Bearer " + giorgosToken)
                .when()
                .get("http://localhost:8081/api/finance/data")
                .then()
                .statusCode(200)
                .body("department", equalTo("Finance"));
    }

    // TC-020 / REQ-014: a non-Finance department user must be denied.
    @Test
    void financeDataDeniesNonFinanceUser() {
        given()
                .header("Authorization", "Bearer " + nikosToken)
                .when()
                .get("http://localhost:8081/api/finance/data")
                .then()
                .statusCode(403);
    }

    // TC-021 / REQ-015: a manager, in any department, must be able
    // to access the manager dashboard. Nikos is IT here deliberately
    // - this checks the role dimension, independent of department.
    @Test
    void managerDashboardAllowsManager() {
        given()
                .header("Authorization", "Bearer " + nikosToken)
                .when()
                .get("http://localhost:8081/api/manager/dashboard")
                .then()
                .statusCode(200);
    }

    // TC-022 / REQ-015: a non-manager (employee only) must be
    // denied.
    @Test
    void managerDashboardDeniesNonManager() {
        given()
                .header("Authorization", "Bearer " + mariaToken)
                .when()
                .get("http://localhost:8081/api/manager/dashboard")
                .then()
                .statusCode(403);
    }

    // TC-023 / REQ-016: requires BOTH department-it AND it-admin
    // together. Nikos has both.
    @Test
    void itAdminAllowsUserWithBothGroupAndRole() {
        given()
                .header("Authorization", "Bearer " + nikosToken)
                .when()
                .get("http://localhost:8081/api/it/admin")
                .then()
                .statusCode(200);
    }

    // TC-024 / REQ-016: a user missing department-it, it-admin, or
    // both must be denied. Giorgos has neither.
    @Test
    void itAdminDeniesUserMissingGroupOrRole() {
        given()
                .header("Authorization", "Bearer " + giorgosToken)
                .when()
                .get("http://localhost:8081/api/it/admin")
                .then()
                .statusCode(403);
    }
}
