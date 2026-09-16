package com.acme.acme_api;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.server.resource.introspection.OAuth2IntrospectionAuthenticatedPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class WhoAmIController {

    // /api/whoami — REQ-012 baseline check. Deliberately no
    // authorization logic beyond "is this token active" (Spring
    // Security already enforced that before this method even runs —
    // if the token were inactive, the request would already have
    // been rejected with 401, this code would never execute).
    @GetMapping("/api/whoami")
    public Map<String, Object> whoAmI(Authentication authentication) {
        OAuth2IntrospectionAuthenticatedPrincipal principal =
                (OAuth2IntrospectionAuthenticatedPrincipal) authentication.getPrincipal();

        return Map.of(
                "username", principal.getAttribute("username"),
                "groups", principal.getAttribute("groups"),
                "active", principal.getAttribute("active")
        );
    }
}
