# GAMATUBE Architecture

GAMATUBE is engineered using a clean, layered multi-platform architecture maximizing code reuse and maintainability across Android, iOS, Windows, macOS, Linux, and Web.

```
                    ┌─────────────────────────┐
                    │   Presentation Layer    │
                    │  Screens, Widgets, UI   │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │    Application Layer    │
                    │ ChangeNotifiers/Providers│
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │      Domain Layer       │
                    │ Models, Capabilities,   │
                    │ Failures, Repositories  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │  Infrastructure Layer   │
                    │ YouTube API, SQLite,    │
                    │ OAuth, LRU Cache, Net   │
                    └─────────────────────────┘
```

---

## Layer Breakdown

### 1. Presentation (`lib/home`, `lib/playback`, `lib/search`, `lib/settings`, `lib/widgets`)
- **Responsive Scaffold:** Dynamically renders desktop sidebar navigation rails on viewports >= 900px and bottom navigation bars on mobile devices.
- **Adaptive Widgets:** Reusable video cards supporting standard vertical cards and compact horizontal search/playlist rows.
- **Design Tokens:** Theme configuration managing Material 3, Dark Slate, AMOLED Pure Black, and High Contrast palettes.

### 2. Application (`lib/providers`)
- **State Management:** Reactive `ChangeNotifier` classes provided via `MultiProvider`.
- **Deduplication:** Debounced search queries and inflight HTTP request sharing.
- **Playback Tracking:** Background timer persisting playback position every 5 seconds without blocking the UI thread.

### 3. Domain (`lib/models`, `lib/core/capabilities`, `lib/core/errors`)
- **Immutability:** Strongly typed models (`Video`, `Channel`, `Playlist`, `WatchHistoryItem`).
- **Capability Engine:** `PlatformCapabilities` declaring granular feature statuses (`SUPPORTED`, `AUTH_REQUIRED`, `UNSUPPORTED`) to keep the UI decoupled from provider limitations.

### 4. Infrastructure (`lib/api`, `lib/auth`, `lib/core/storage`)
- **Video Platform Service:** Abstraction over official YouTube Data API v3 with quota tracking, backoff retries, and offline fallback catalog.
- **Cache Manager:** In-memory LRU cache with TTL invalidation, MD5 query hashing, and configurable disk boundaries.
- **Local Store:** Asynchronous typed persistent store for settings, history, and offline collections.
