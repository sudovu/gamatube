# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

---

## Security Commitments

GAMATUBE is engineered according to modern security principles:

1. **No Embedded Secrets:**
   - Source code contains zero hard-coded API keys, client secrets, or private tokens.
   - All external keys must be configured via `.env` or user-supplied runtime preferences.

2. **Official API & Legal Rules:**
   - Does not bypass DRM, geoblocking, or access controls.
   - Does not reverse-engineer private endpoints.
   - Does not use patched binaries, microG, Magisk, or root modifications.
   - Communicates exclusively over TLS/HTTPS with cleartext traffic disabled.

3. **Credential & Token Protection:**
   - Passwords and Google credentials are never handled directly.
   - Authentication relies strictly on official OAuth 2.0 PKCE authentication flows.
   - Structured logs automatically scrub potential tokens (`ya29.*`, `Bearer *`, etc.) before output.

4. **Input Sanitization & Storage Safety:**
   - Local database queries are parameterized and serialized with strong types.
   - External data fetched over network is validated before consumption.

---

## Reporting a Vulnerability

If you discover a potential security vulnerability within GAMATUBE, please report it responsibly:
- Email: security@gamatube.local or submit a confidential advisory on GitHub.
- Do not disclose vulnerabilities publicly until a fix has been prepared and published.
