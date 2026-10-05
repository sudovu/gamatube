# Google Authentication Guide

GAMATUBE supports Google Account authentication using official Google OAuth 2.0 PKCE.

---

## Security Invariants

- **No Passwords Stored:** GAMATUBE never prompts for, reads, or records Google Account passwords.
- **PKCE (Proof Key for Code Exchange):** Cryptographic `code_verifier` and `code_challenge` SHA-256 tokens guard against interception attacks.
- **Optional Sign-In:** The entire core application (browsing, search, local playlists, watch history, playback, custom API keys) works without an account.

---

## Configuring Your Google OAuth Credentials

To enable Google sign-in with your own Google Cloud project:

1. Visit the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. Enable the **YouTube Data API v3** under **APIs & Services > Library**.
4. Go to **APIs & Services > Credentials** and click **Create Credentials > OAuth client ID**.
5. Select application type:
   - For Web: Add `http://localhost:8080/callback` (or your domain).
   - For Desktop / Mobile: Choose Desktop app or Android/iOS client.
6. Copy the **Client ID** into `.env`:
   ```bash
   GOOGLE_OAUTH_CLIENT_ID=your_client_id_here
   ```
