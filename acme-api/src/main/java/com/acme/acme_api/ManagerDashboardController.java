package com.acme.acme_api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.introspection.OAuth2IntrospectionAuthenticatedPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class ManagerDashboardController {

    // /api/manager/dashboard — REQ-015. Deliberately checks ROLE, not
    // group/department — this is the first endpoint that exercises
    // the other independent dimension of the model (ADR-0001).
    // A manager in any department (e.g. Nikos, IT) must be allowed;
    // an employee in any department (e.g. Maria, HR) must not.
    @GetMapping("/api/manager/dashboard")
    public ResponseEntity<?> managerDashboard(Authentication authentication) {
        OAuth2IntrospectionAuthenticatedPrincipal principal =
                (OAuth2IntrospectionAuthenticatedPrincipal) authentication.getPrincipal();

        // Unlike "groups" (a flat list), roles come nested inside
        // "realm_access": { "roles": [...] } — matches exactly what
        // we already saw in the decoded introspection response.
        Map<String, Object> realmAccess = principal.getAttribute("realm_access");
        List<String> roles = (realmAccess != null)
                ? (List<String>) realmAccess.get("roles")
                : null;

        if (roles == null || !roles.contains("manager")) {
            return ResponseEntity.status(403).build();
        }

        return ResponseEntity.ok(Map.of(
                "message", "Welcome to the manager dashboard"
        ));
    }
}
