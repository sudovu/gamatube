# Changelog

All notable changes to the GAMATUBE project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-06

### Redesigned & Added
- **Icon Redesign:** Created high-resolution crimson play-pill launcher icon (`ic_launcher.png`) across all Android density buckets (`mdpi` through `xxxhdpi`) and Web PWA icons.
- **YouTube-Lookalike Aesthetics & Palette:**
  - Iconic YouTube Red (`#FF0000`) accent with signature `#0F0F0F` dark mode background and `#272727` surface cards/chips.
  - Top App Bar with GamaTube brand play badge, Cast button, Notifications bell with unread badge, Search button, and user profile avatar.
  - YouTube-style Topic Bar with Compass / Explore anchor and high-contrast selected pill chips.
  - Flush edge-to-edge Video Cards with 12px rounded thumbnails, dark duration badge overlay (`12:45`), channel avatars, 2-line clean titles, and 3-dot kebab menu.
- **Shorts Experience:**
  - Dedicated interactive Shorts Shelf carousel in Home feed.
  - Immersive vertical 9:16 Shorts Screen tab with like/dislike buttons, comments modal, share, and subscribe pill.
- **Video Player Polish:**
  - High-contrast pill Subscribe button with bell notification state.
  - Segmented Like / Dislike pill (`👍 124K | 👎`), Share pill, Summary pill, Download notice pill, and Save pill.
  - Tappable Comments preview card opening an interactive DraggableScrollableSheet comments modal.
- **Modern "You" Screen:**
  - User profile header with handle, switch account, and Google account management.
  - Recent watch history carousel with red progress indicators.
  - Playlists carousel with Watch Later and Liked Videos.
- **Navigation:**
  - Modern YouTube 4-tab bottom navigation: Home, Shorts, Subscriptions, and You.

## [1.0.0] - 2026-10-06

### Added
- **Multi-Platform Support:** Ready across Android, Windows, Web, iOS, macOS, and Linux.
- **Modern GAMATUBE Design System:** Original branding and typography with Light, Dark (Slate), AMOLED Pure Black, and High Contrast themes.
- **Home Feed & Discovery:** Responsive video feeds, category filter chips (Music, Gaming, Podcasts, Tech), and "Continue Watching" playback carousel.
- **Fast Debounced Search:** Query search with local history caching, suggestions, and relevance/view/date sorting.
- **Compliant Playback Engine:** Official YouTube IFrame Player integration with play, pause, seek (+/- 10s), speed adjustment, and caption support.
- **Smart Playback Tracking:** Local watch history with timestamp resolution, completion tracking, and automatic resume prompting.
- **Local Collections:** Local playlists and "Watch Later" queue stored offline without account requirement.
- **Google OAuth 2.0 PKCE:** Secure sign-in to sync subscriptions and account-level feeds.
- **Privacy-Preserving AI Summaries:** Local heuristic extraction of video overviews, key takeaways, and action items.
- **Smart Cache Engine:** LRU eviction, TTL invalidation, and user-configurable cache capacity limits (100 MB – 1 GB).
- **First-Run Onboarding Wizard:** Intuitive step-by-step setup for theme, account, and preferences.
- **Zero Injected Ads:** Ad-free client experience with strict adherence to official platform terms.
