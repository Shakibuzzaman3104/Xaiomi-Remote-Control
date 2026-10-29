# Xiaomi Remote — Device Findings, Features & Plan (v0 → v2)

_Tested live on 29/10/26 against the real box._

## 1. The device

| | |
|---|---|
| Model | Xiaomi **Mi Box S** (`MIBOX4`, board `oneday`, Amlogic) |
| OS | Android TV **9** (API 28), build PI.3933, patch 2021-07-05, `user` build (no root) |
| CPU / RAM / free storage | armeabi-v7a (32-bit) / 2 GB / **~780 MB free (85% full)** |
| UI resolution | 1920×1080 @ 320 dpi (all tap coordinates use this space) |
| Network | `192.168.0.103`, mDNS host `Android.local` |
| Services | Remote v2 `6466/6467` · ADB `5555` (legacy TCP, authorized) · Cast `8008/8009` · Xiaomi HTTP `6095` **closed** |
| Remote service | `com.google.android.tv.remote.service` 7.00 — features: **KEY, IME, VOICE, POWER, VOLUME, APP_LINK, PING** |
| Physical remote | "Xiaomi RC", Bluetooth LE |
| HDMI-CEC | **Off** |
| Launcher apps | 52 (YouTube, Netflix, Hoichoi, Toffee, Hotstar, SonyLIV, Plex, VLC, Stremio, ISP Stream…) |

## 2. What works and what doesn't (tested)

### ✅ Verified working
| Capability | Channel | Notes |
|---|---|---|
| Auto-discovery | mDNS | `_androidtvremote2._tcp`, `_googlecast._tcp`, `_adb._tcp` |
| Pairing | Remote v2 | 6-char hex code on TV. With ADB the app can **read the code itself** (screencap + OCR) → zero-typing pairing |
| All remote keys (D-pad, Home, Back, media…) | Remote v2 / ADB | |
| Launch app / deep link | Remote v2 `APP_LINK` | e.g. `https://www.youtube.com/watch?v=…` |
| Current foreground app | Remote v2 push | Live updates |
| Text into TV fields, **incl. Bangla** | Remote v2 IME | TV announces when a field gets focus → phone keyboard can auto-open. **Must echo `counter_field` from `remote_ime_key_inject`** (the Python lib gets this wrong) |
| Text via ADB `input text` | ADB | ASCII only |
| Voice → Assistant (as text) | ADB | Phone STT → `GLOBAL_SEARCH` intent → Assistant answers on TV (tested "weather in Dhaka") |
| Screenshots of UI | ADB | `screencap` |
| Screen stream (H.264) | ADB | `screenrecord` / scrcpy-server possible |
| Read UI tree / focused element | ADB | `uiautomator dump`. **Flaky**: worked once, failed in YouTube and the browser |
| Now playing | ADB | Title, channel, state, position from `media_session` (YouTube verified) |
| App list (52 launcher apps) | ADB | `pm` / `cmd package` |
| Sleep | ADB | `KEYCODE_SLEEP` (Remote v2 `POWER` not yet tested) |
| Volume ± | R / ADB | Changes the HDMI stream (0–15). Remote v2 reports `max=0`, so read the level via ADB |
| Reconnect after wake | R / ADB | No re-pairing, no new ADB prompt. Box needed ~1 min after the remote press |
| Write secure + global settings | ADB | Write and read-back verified, so the companion a11y service can be enabled remotely |
| Force-stop apps | ADB | Verified on VLC |

### 🟡 Expected, not yet tested
| Capability | Ch | Why we expect it |
|---|---|---|
| Install / uninstall APKs | ADB | Shell holds `INSTALL_PACKAGES`; no APK installed yet |
| Sleep via Remote v2 `POWER` | R | Feature flag present |

### ❌ Not possible on this box
| Capability | Why |
|---|---|
| **Video in screenshots/mirroring** | Amlogic draws video on a hardware overlay. Even non-DRM YouTube captures black. Mirror shows UI only |
| **Wake from sleep over Wi-Fi** | In sleep, Wi-Fi is fully off (no ping, no ports for 60 s+). Inferred, not tested: no WoL packet was sent because the MAC was unknown. Wake = physical remote (or BT, see below) |
| Bangla in YouTube's search | YouTube uses its own Latin-only keyboard; system fields are fine |
| Control the TV set (power/input/volume) | HDMI-CEC is off. User can enable it in box settings → then box power controls TV |
| Root-level actions | `user` build |

### ⚠️ Unverified (spikes needed)
| Capability | Spike |
|---|---|
| Remote v2 native voice with real mic audio | Session opens and Assistant listens; synthetic `say` audio was not recognised. Test with real phone mic PCM |
| Wake via Bluetooth | Phone registers as BLE/BT HID remote (`BluetoothHidDevice`, Android 9+ phone) and sends POWER |
| HDMI-CEC once enabled | TV on/off and volume through the box |

## 3. Architecture

- **Platform:** Flutter app, **Android phone only** for v0–v2 (ADB, mirroring and BT-HID need Android). The Remote v2 layer is pure Dart, so iOS can follow later with a reduced feature set.
- **Channels, layered (app works on 1, unlocks more with 2–4):**
  1. **Remote v2** — Dart: TLS client cert + protobuf (polo pairing + remote messages). Primary channel for keys, text, apps, voice.
  2. **ADB** — Kotlin (`dadb`) behind a platform channel. Phone RSA key → TV shows "Allow debugging?" once → accept with the physical remote ("Always allow").
  3. **Pushed helper (no install)** — `scrcpy-server` jar pushed to `/data/local/tmp`, run via `app_process`: H.264 mirror, touch injection, clipboard (Unicode paste).
  4. **Companion APK (v2)** — tiny armv7 app with an AccessibilityService: on-screen mouse cursor, gesture taps, app icons/labels, clipboard sync. Installed and enabled entirely over ADB.
- **State:** Riverpod; one `TvSession` per device aggregating channel states.
- **Storage:** paired cert/key + ADB key in Android Keystore-backed secure storage.

## 4. Features by phase

Legend: **R** = Remote v2, **A** = ADB, **H** = pushed helper, **C** = companion APK, **P** = phone-side only.

### v0 — MVP: "replace the physical remote"
| Feature | Ch |
|---|---|
| mDNS discovery, device card (name, model, IP, status) | P |
| Pairing with code entry; store certs; auto-reconnect; keep-alive | R |
| Remote screen: D-pad ring + OK, Back, Home, Menu/Settings, Power(sleep) | R |
| Volume ± / mute, media keys (play/pause, ±seek, next/prev) | R |
| Hold-to-repeat, haptics on every press | P |
| Keyboard: auto-opens when TV field focused; live sync; Bangla + all Unicode; send/enter | R |
| Voice button: phone STT (Bangla + English) → typed into focused field, or → Assistant search | R/A* |
| App dock: favourite apps via deep links (YouTube, Netflix, Hoichoi, Toffee…) | R |
| Current-app indicator | R |

_*Assistant search needs ADB; without ADB voice falls back to dictation into the focused field._

**Acceptance:** pair from scratch in < 60 s; key latency < 150 ms on LAN; reconnect after Wi-Fi blip < 3 s; Bangla text lands in a system text field; voice query opens Assistant result.

### v1 — "full control" (ADB unlocked)
| Feature | Ch |
|---|---|
| Guided ADB onboarding (dev options steps, accept dialog with remote, status check) | A |
| **Auto-pairing**: read pairing code from TV screen via screencap + OCR | A |
| Swipe pad mode (swipe = D-pad, tap = OK, 2-finger = Back, hold = scroll) | R |
| Number pad / channel keys | R |
| Volume slider with real level (0–15) | A |
| **Now Playing** card: title, channel/app, play state, position, scrub | A |
| Apps screen: all 52 launcher apps, launch, force-stop, clear cache, uninstall, app info | A |
| APK sideload from phone (shows free space, fails gracefully when < size) | A |
| Screenshot to phone (gallery/share) | A |
| Device info: model, OS, storage, RAM, uptime | A |
| Persistent notification remote + lock-screen controls; Quick Settings tile | P |
| Phone volume keys → TV volume while app foreground | P |
| Sleep timer (sleep after N min) | A |
| Onboarding tip: enable HDMI-CEC to control the TV set | P |

**Acceptance:** all features work on the Mi Box after one ADB authorization; app list loads < 2 s; sideload of a 50 MB APK succeeds with progress; now-playing updates within 1 s of state change.

### v2 — "power user"
| Feature | Ch |
|---|---|
| **Live mirror** (UI only — video area shows black; labelled in UI), tap-on-mirror to control | H |
| **Mouse / trackpad mode** with on-TV cursor, click, scroll, drag | C |
| **Air mouse** (gyro) | C |
| App icons + labels in Apps grid | C |
| Clipboard sync phone ↔ TV | H/C |
| Send to TV: phone videos/photos/files (phone HTTP server → VLC / viewer intent) | A |
| Open URL on TV (browser) | A |
| Macros: recorded or built sequences (keys, apps, text, delays) | R/A |
| Custom remote layouts (drag any key/action/macro onto a page) | P |
| Raw keycode sender + ADB shell console with saved commands | A |
| Native voice streaming to Assistant (if spike passes) | R |
| Bluetooth HID mode: control + **wake from sleep** (if spike passes) | BT |
| Home-screen widgets (mini remote, app shortcuts) | P |

**Acceptance:** mirror ≥ 20 fps at 720p, < 300 ms latency; cursor tracks finger with no visible lag; companion installs + enables with one tap; macros replay reliably 10/10.

## 5. Screens (input for design)
1. **Onboarding** — discover → pair → (optional) unlock full control → CEC tip
2. **Remote (home)** — mode tabs: D-pad · Swipe · Mouse · Numpad; persistent bar: mic, keyboard, power; app dock; now-playing strip
3. **Keyboard sheet** — auto-opens on TV focus, live text mirror, Bangla/English
4. **Voice overlay** — listening, transcript, target (field vs Assistant)
5. **Apps** — grid, search, per-app actions sheet
6. **Now Playing** — artwork/title, scrub, transport, volume
7. **Mirror** — live UI view, tap to control
8. **Tools** — macros, custom layouts, file/URL send, shell, device info
9. **Settings** — devices, haptics, gestures, voice mode, theme

## 6. Build order
1. Remote v2 Dart client (pairing, keys, IME w/ correct counters, app link) + discovery
2. v0 UI on top → dogfood on the Mi Box
3. ADB bridge (Kotlin dadb) + onboarding → v1 features
4. Spikes: native voice, BT HID wake
5. scrcpy-server integration → mirror; companion APK → mouse; then macros/layouts
