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
}
