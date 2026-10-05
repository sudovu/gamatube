# Platform Support Matrix

GAMATUBE is engineered for maximum cross-platform reach using a shared Flutter codebase.

| Platform | Tier | Status | Artifact / Delivery |
| -------- | ---- | ------ | -------------------- |
| **Android** | Tier 1 | Fully Supported | APK (`assembleRelease`), AAB (`bundleRelease`) |
| **Windows Desktop** | Tier 1 | Fully Supported | Windows 64-bit native executable / MSIX |
| **Web** | Tier 1 | Fully Supported | Single Page PWA bundle (`build/web`) |
| **iOS / iPadOS** | Tier 1 | Archive-Ready | Xcode Workspace / Project ready for macOS compilation |
| **macOS** | Tier 2 | Archive-Ready | macOS runner project ready for Xcode compilation |
| **Linux** | Tier 2 | Archive-Ready | Linux GTK CMake runner ready for Linux compilation |

---

## Hardware Optimization Targets

- **Low-End Devices (2 GB – 3 GB RAM):**
  - "Low-End Device Mode" in Settings reduces animation budgets.
  - "Data Saver" selects lower-resolution thumbnails, reducing GPU memory footprint.
  - Pagination limits concurrent image prefetching.
- **High-Performance Workstations & Tablets:**
  - Responsive multi-column grid layout (up to 4 columns).
  - Sidebar navigation rail maximizing wide horizontal aspect ratios.
