package com.acme.acme_api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.introspection.OAuth2IntrospectionAuthenticatedPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class ItDataController {

    // /api/it/data — REQ-013. Requires department-it. Authentication
    // (is the token valid?) was already handled by Spring Security
    // before this method runs. This method handles ONLY authorization
    // (does THIS user have the right group for THIS endpoint?) —
    // deliberately kept as an explicit, visible check here rather
    // than hidden behind a framework annotation, so the logic stays
    // easy to trace to REQ-013 directly.
    @GetMapping("/api/it/data")
    public ResponseEntity<?> itData(Authentication authentication) {
        OAuth2IntrospectionAuthenticatedPrincipal principal =
                (OAuth2IntrospectionAuthenticatedPrincipal) authentication.getPrincipal();

        List<String> groups = principal.getAttribute("groups");

        if (groups == null || !groups.contains("department-it")) {
            return ResponseEntity.status(403).build();
        }

        return ResponseEntity.ok(Map.of(
                "department", "IT",
                "message", "Welcome to IT data"
        ));
    }
}
