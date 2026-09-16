package com.acme.acme_api;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.introspection.OAuth2IntrospectionAuthenticatedPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
public class FinanceDataController {

    // /api/finance/data — REQ-014. Same pattern as /api/it/data
    // (ItDataController): authentication already handled by Spring
    // Security; this method only checks authorization for THIS
    // specific department.
    @GetMapping("/api/finance/data")
    public ResponseEntity<?> financeData(Authentication authentication) {
        OAuth2IntrospectionAuthenticatedPrincipal principal =
                (OAuth2IntrospectionAuthenticatedPrincipal) authentication.getPrincipal();

        List<String> groups = principal.getAttribute("groups");

        if (groups == null || !groups.contains("department-finance")) {
            return ResponseEntity.status(403).build();
        }

        return ResponseEntity.ok(Map.of(
                "department", "Finance",
                "message", "Welcome to Finance data"
        ));
    }
}
