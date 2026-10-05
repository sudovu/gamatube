# Privacy Policy for GAMATUBE

**Last Updated:** October 2026

GAMATUBE is engineered from the ground up as a **privacy-conscious, lightweight personal video platform client**. We believe that your watching habits, search queries, and media history belong strictly to you.

---

## 1. Guiding Principles

- **Zero Advertising Injection:** GAMATUBE does not insert banner ads, popups, video pre-rolls, or tracking pixels.
- **Zero Third-Party Data Brokers:** We never monetize, package, share, or sell your personal data.
- **Local-First Architecture:** Your watch history, local playlists, watch later collection, and UI settings reside on your device.
- **Opt-In Diagnostics:** Analytics and crash reporting are disabled by default and require explicit user opt-in in Settings.

---

## 2. Information We Store Locally

All operational data is persisted locally in device storage:
- **Watch History:** Stored on your device to let you resume videos and track completion. Can be paused or cleared anytime in Settings.
- **Local Playlists & Watch Later:** Created and indexed directly on your local device.
- **Search History:** Cached locally to offer autocomplete and quick access. Can be wiped with one tap.
- **Client Cache:** Temporary HTTP responses and thumbnail images cached with LRU eviction and user-configurable size caps (100 MB – 1 GB).

---

## 3. Account Authentication & External Services

- **Google Account Sign-In (Optional):** If you choose to sign in, GAMATUBE uses official OAuth 2.0 PKCE protocols. We **never** view, request, or store your Google password. Only the minimum necessary tokens required to sync subscriptions and playlists are held.
- **Official YouTube Data API:** Video queries are dispatched directly to documented, official Google YouTube API endpoints. GAMATUBE complies with YouTube's Terms of Service and does not circumvent access restrictions.

---

## 4. User Controls & Data Purging

You maintain total sovereignty over your local footprint:
- **Pause History:** Toggle "Pause Watch History" in Settings to halt tracking.
- **Clear Cache:** Instantly purge all temporary cached metadata and images.
- **Reset Local Data:** The "Clear All Local Data" button immediately wipes all history, playlists, cached sessions, and preferences from your device.

---

## 5. Security & Secret Protection

GAMATUBE implements strict secret scrubbing in its logging layer. No OAuth tokens, access tokens, client secrets, or private identifiers are ever written to console output or persistent disk logs.
