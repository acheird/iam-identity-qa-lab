package com.acme.acme_api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.introspection.OAuth2IntrospectionAuthenticatedPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class ItAdminController {

    // /api/it/admin — REQ-016. Requires BOTH department-it (group)
    // AND it-admin (role) together — deliberately separate from
    // /api/it/data (REQ-013, group only), so a plain IT employee
    // and an admin from a different department are both correctly
    // excluded, for different reasons.
    @GetMapping("/api/it/admin")
    public ResponseEntity<?> itAdmin(Authentication authentication) {
        OAuth2IntrospectionAuthenticatedPrincipal principal =
                (OAuth2IntrospectionAuthenticatedPrincipal) authentication.getPrincipal();

        List<String> groups = principal.getAttribute("groups");
        Map<String, Object> realmAccess = principal.getAttribute("realm_access");
        List<String> roles = (realmAccess != null)
                ? (List<String>) realmAccess.get("roles")
                : null;

        boolean hasItGroup = groups != null && groups.contains("department-it");
        boolean hasItAdminRole = roles != null && roles.contains("it-admin");

        if (!hasItGroup || !hasItAdminRole) {
            return ResponseEntity.status(403).build();
        }

        return ResponseEntity.ok(Map.of(
                "message", "Welcome to IT administration"
        ));
    }
}
