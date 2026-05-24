# LazyPacket — Native macOS 26 Redesign

Goal: fully native, system-native adaptive UI (light/dark + accent color), Liquid Glass,
native toolbar/List/searchable, working commands & haptics. Verify with a build each phase.

Baseline: builds clean on Xcode 26.5 / macOS 26.5 SDK. Deployment target macOS 26.0.

## Phase 1 — Adaptive color system  (Colors.swift)
- [x] Replace hardcoded dark RGB with semantic NSColor-backed adaptive colors
- [x] Route `primaryBlue` → `Color.accentColor` (respect system accent)
- [x] backgrounds → windowBackground / material; borders → separatorColor
- [x] Keep status colors as system green/orange/red (auto-adaptive)

## Phase 2 — App shell: toolbar + commands  (LazyPacketApp.swift, ContentView.swift)
- [x] Lift viewModel to App level (shared @StateObject) so commands can reach it
- [x] Native unified toolbar: Add Device, Refresh status
- [x] Wire ⌘N (Add), ⇧⌘W (Wake selected), ⌘R (Refresh), ⌘⌫ (Delete) — real actions,
      auto-enable/disable on selection. (Avoided hijacking ⌘W = close window.)

## Phase 3 — Sidebar  (DeviceSidebarView.swift)
- [x] Replace custom ScrollView/tap-gesture with `List(selection:)` + `.listStyle(.sidebar)`
- [x] `.searchable()` instead of hand-rolled search bar
- [x] Selection binding ↔ viewModel.selectedDevice (keyboard nav for free)
- [x] Show device-type icon in each row; status dot on trailing edge

## Phase 4 — Detail view  (MainContentView.swift, AddDeviceSheet.swift)
- [x] Native button styles (.borderedProminent / .bordered + .tint(.red))
- [x] Adaptive text fields with live MAC validation tinting
- [x] Cards → .regularMaterial (vibrant, light/dark correct)
- [x] Add Device sheet right-sized (480×620) + ⏎ to confirm

## Phase 5 — Haptics  (WakeOnLANViewModel.swift)
- [x] Implement macOS path via NSHapticFeedbackManager (was iOS-only no-op)

## Phase 6 — Cleanup + verify
- [~] ModernViewController.swift left in place (dead, not in build) — flagged, not deleted
- [x] Full build SUCCEEDED; app launches without crashing

## Review

**Outcome:** LazyPacket now adapts to Light/Dark mode and the system accent color,
uses the native unified toolbar, a native sidebar `List` with real keyboard
navigation and selection, `.searchable`, native bordered/prominent buttons, and
material card surfaces. Menu commands and macOS trackpad haptics actually work now.

**Verified:** `xcodebuild` clean (only 2 pre-existing warnings in WakeOnLANViewModel,
unrelated to this work); app launches and runs without crashing. Could NOT capture a
screenshot — Screen Recording permission is denied to the shell in this environment.

**Files changed:** Colors.swift, LazyPacketApp.swift, ContentView.swift,
DeviceSidebarView.swift, MainContentView.swift, AddDeviceSheet.swift, WakeOnLANViewModel.swift.

**Recommended follow-ups (not done):**
- Delete dead `ModernViewController.swift` (32 KB, not referenced by the build).
- Fix the 2 pre-existing warnings in WakeOnLANViewModel.swift (unused `lastOctet`; redundant `await`).
- Consider `.glassEffect()` on the detail cards for a stronger Liquid Glass look once
  tested against real content.
