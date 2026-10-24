# iTantra Tactical System Architecture & Screen Flow Guide
> **Smart India Hackathon (SIH 2026) Project Master Guide**  
> Complete operational roadmap, screen navigation flowcharts, button interaction mechanics, and technical construction blueprints.

---

## 🗺️ 1. Master Navigation & System Architecture Flowchart

```text
                               ┌────────────────────────────────┐
                               │   Screen 0: Home Dashboard     │
                               │  (Brand hero, mesh counters,   │
                               │   surfaces, field records)     │
                               └───────────────┬────────────────┘
                                                │
                                                ▼ (Tap "Get Started →")
                               ┌────────────────────────────────┐
                               │   Screen 1B: Language Pack     │
                               │   Selection                    │
                               │  (Search, 10 packs, voice      │
                               │   preview, confirm)            │
                               └───────────────┬────────────────┘
                                                │
                                                ▼ (Tap "Confirm & Continue →")
                               ┌────────────────────────────────┐
                               │   Screen 1: Splash & Setup     │
                               │  (Device ID, Role, Permissions)│
                               └───────────────┬────────────────┘
                                                 │
                                                 ▼ (Tap "Enter Tactical Comms")
  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                  UNIFIED COMMS HUB (Screen 2 + Screen 6 in one shell)                    │
  │                                                                                                         │
  │  ┌───────────────────────────────────────────────────────────────────────────────────────────────────┐  │
  │  │  App Bar : ◀ Back │ [⌁ iTantra / Hindi · hi] │ ● Mesh Active │ ☰ Tactical Menu                   │  │
  │  ├───────────────────────────────────────────────────────────────────────────────────────────────────┤  │
  │  │  IndexedStack body                                                                               │  │
  │  │   ┌────────────────────────────────┐   ┌────────────────────────────────┐                          │  │
  │  │   │ SENDER SURFACE                │   │ RECEIVER SURFACE              │                          │  │
  │  │   │ Link capsule · PTT hero ·      │   │ Signal vector · Listen pipeline│                          │  │
  │  │   │ waveform · Recorded Audio card │   │ Quick reply · Replay queue     │                          │  │
  │  │   │ · Live Transcript · Last Msg   │   │                                │                          │  │
  │  │   └────────────────────────────────┘   └────────────────────────────────┘                          │  │
  │  ├───────────────────────────────────────────────────────────────────────────────────────────────────┤  │
  │  │  Composer : "Type message" [Send ▶]        (sender mode only, keyboard safe)                     │  │
  │  ├───────────────────────────────────────────────────────────────────────────────────────────────────┤  │
  │  │  Mode Dock :  🎤 SENDER   |   🎧 RECEIVER   (emerald indicator line on the active tab)          │  │
  │  └───────────────────────────────────────────────────────────────────────────────────────────────────┘  │
  │                                                                                                         │
  │  ☰ Tactical Menu → Radar · Comms Log · Radio Manager · Language Packs                                  │
  └──────────────────────────────────┬──────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (Dock / Menu tap on the secondary surfaces)
  ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                       SECONDARY SURFACES                                               │
  │                                                                                                         │
  │  ┌───────────────────────────┐   ┌───────────────────────────┐   ┌───────────────────────────────────┐  │
  │  │ Screen 3: Tactical Radar  │   │ Screen 4: Comms Log &     │   │ Screen 5: Radio Manager &         │  │
  │  │ (360° Compass + Distance) │   │ Offline Retry Queue       │   │ Screen 6: Language Pack Manager   │  │
  │  └───────────────────────────┘   └───────────────────────────┘   └───────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼ (Dock tap "Sender" / "Receiver")
                                     └──────────────► back to the single UNIFIED COMMS HUB

                                 Incoming Packet has Type == 0x02 (ALERT)
                                                ▼
                                ┌────────────────────────────────────────┐
                                │ Screen 7 / Overlay: Emergency Siren    │
                                │ (100% Volume, Unskippable Red Modal)   │
                                └────────────────────────────────────────┘
```

### Router Map (`lib/core/router/app_router.dart`)

| Route | Screen | Notes |
| :--- | :--- | :--- |
| `/` | Home Dashboard | App entry point. Same page as `/dashboard`. |
| `/dashboard` | Home Dashboard | Alias of `/`, handy for deep links. |
| `/select-language` | Language Pack Selection | Sits between the dashboard and the hub. |
| `/setup` | Splash & Setup | Device identity, role and permissions. |
| `/comms` | Unified Comms Hub | Canonical entry. Sender mode by default. |
| `/home` | Unified Comms Hub | Legacy alias → hub in sender mode. |
| `/receiver` | Unified Comms Hub | Legacy alias → hub in receiver mode. |
| `/radar` | Tactical Radar | Pushed on top of the hub. |
| `/logs` | Comms Log | Sibling tab, replaces the previous sibling. |
| `/radio` | Radio Manager | Reachable from the tactical menu. |
| `/language` | Language Pack Manager | Reachable from the tactical menu. |

The operator path is **`/` → `/select-language` → `/comms`** (sender) and
**`/` → `/select-language` → `/comms`** (receiver, via the mode dock). The
`Confirm & Continue` button of the picker pops itself off the stack and, when
a hub is already open underneath, simply returns to it — the router never
grows a duplicate hub.

`DockDestination` drives every dock tap: sender and receiver always resolve back
to the **single** hub instance (`Navigator.popUntil` + `CommsHubState.mode`), while
sibling surfaces replace each other so the router never grows a duplicate hub.

`MaterialApp.onGenerateInitialRoutes` is overridden in `lib/main.dart`, so the app
boots with a **single** entry route. Without it MaterialApp pushes a hidden `/`
route under every other start route and the dashboard would boot twice.

### Theme System (`lib/core/theme/app_theme.dart`)

iTantra v2.0 ships the **Light Neural** system described in [`design.md`](file:///d:/itantra/design.md):

* **`AppColors`** — the complete semantic token set (white scaffold `#FFFFFF`,
  slate-50 fills `#F8FAFC`, Forest Emerald `#00875A` / `#059669`, mint tints
  `#ECFDF5` / `#A7F3D0` / `#DCFCE7`, alert rose `#FEF2F2`, slate text
  `#0F172A` / `#64748B` / `#94A3B8`) plus the pastel language swatches.
* **`AppFonts`** — the bundled type stack. `PlusJakartaSans` is the primary
  Latin/UI face; nine Noto Sans families (Devanagari, Gujarati, Kannada,
  Malayalam, Tamil, Telugu, Oriya, Bengali, Gurmukhi) are registered as
  `fontFamilyFallback`, so every native script renders offline and never
  clips a matra. `AppFonts.forLanguageCode()` hands a script its own family.
* **`AppTypography`** — the type scale (brand, headline, hero caption, card
  title/body, translation, badge, CTA, micro).
* **`AppTheme.lightTheme`** — the Material 3 light `ThemeData` (card, input,
  button, chip, snack bar, dialog, slider, switch and progress themes).
  `MaterialApp` pins `themeMode: ThemeMode.light`, so the legacy dark tactical
  palette from [`design_v1_dark.md`](file:///d:/itantra/design_v1_dark.md) stays
  available for a future toggle without touching any screen.


---

## 📱 2. Detailed Screen-by-Screen Breakdown

---

### Screen 0: Home Dashboard (App Entry Point)
* **File:** `lib/presentation/screens/home_dashboard_screen.dart`
* **Role:** The first screen of the app. It introduces the product, shows the live state of the mesh and lets the operator jump into any surface — or file a field record — without a single truncated word.

#### A. Visual Layout & UI Components
* **Brand Hero:** Dark slate squircle logo tile (mic glyph, emerald glow), the `iTantra` wordmark, the tagline `Local Neural Speech & Edge Walkie-Talkie`, two feature pills (`10 Indian Languages`, `100% Offline`) and the `Ultra-Low Latency` kicker.
* **Status Strip:** Tap-through card with the node call-sign (or `Node Not Configured`), a live dot and the chips `Mesh Active`, active language and `Edge P2P`.
* **Metric Grid:** Three counters — `Active Nodes`, `Round Trip` and `Ack Rate` — each in a 16 dp radius card with a 40×40 mint icon box.
* **Link Chips:** `Packets <n>`, `Saved <n>%` and `Offline Models 10`.
* **Surfaces Grid:** Full-card `Material` + `InkWell` tiles (PTT, Radar, Comms Log, Radio Manager, Select Language, Device Setup) with a trailing chevron instead of a per-row button.
* **Field Records:** The operator timeline with title, detail, category badge, relative time and a delete action — plus the `Add` chip that opens the add-record form.
* **Bottom CTA:** Full-width emerald `Get Started →` button with the footer caption `Instant Indian Language Synthesizer · Edge P2P`.

#### B. Button Click Mechanics & Navigation
* **"Get Started →" Tap:** Opens the language pack selection screen (`/select-language`). A configured node jumps into the console from there.
* **Status Strip Tap:** Opens the unified comms hub.
* **Surface Tile Tap:** Pushes the matching route (`/radar`, `/logs`, `/radio`, `/select-language`, `/setup`, `/comms`).
* **"Add" Chip Tap:** Opens the keyboard-safe add-record sheet. The form is a modal route with `isScrollControlled: true`, an animated bottom padding that follows the IME and a scrollable body, so the Android keyboard can never clip a field.

#### C. Technical Construction
* **Dependencies:** `flutter_bloc` (`HomeBloc`), `hive` (record store), `shimmer` (loading skeletons), `lottie` (empty and error states), `lucide_icons`.
* **Architecture:** 3-layer — `FieldRecord` DTO → `DashboardRepository` (Hive store with mock seed fallback) → `HomeBloc` (Initial → Loading → Loaded → Error).
* **Computer Networks Concept:** **Edge Resource Management.** The dashboard reports the mesh counters (peers, round trip, ACK rate, bandwidth saved) that the packet layer produces, so the operator sees the link health before the first transmission.

---

### Screen 1B: Language Pack Selection Screen
* **File:** `lib/presentation/screens/language_picker_screen.dart`
* **Role:** The onboarding step between the home dashboard and the comms hub. The operator chooses the working language of the device, hears a voice preview of the pack and only then walks into the sender / receiver surfaces.

#### A. Visual Layout & UI Components
* **App Bar:** Back chevron, the `Select Language` title and the `Pick your working language` caption.
* **Search Field:** A rounded dark field with a search glyph and the hand drawn `Search languages` placeholder (Flutter's own hint is never used, because it would ellipsise).
* **Result Caption:** `10 of 10 languages` — switches to `1 of 10 languages` while the search filters the catalogue.
* **Language Rows:** One card per Indian language with the two letter code badge (`HI`, `GU`, `MR`, …), the native script (`हिन्दी`, `ગુજરાતી`, …), the English name, a sky-blue voice preview button and the emerald selection marker.
* **Bottom CTA:** The full width emerald `Confirm & Continue →` button with the `Offline voice and text for the whole mesh` caption.
* **Empty State:** Lottie artwork plus `No Language Found` when the search matches nothing.

#### B. Button Click Mechanics & Navigation
* **Language Row Tap:** Dispatches `LanguageSelect` — the pack is swapped in RAM, the pointer in `AppConstants` is updated and the choice is persisted to `Hive`.
* **Speaker Button Tap:** Speaks the sample phrase of the pack. Hindi uses the offline Piper model, the other languages fall back to the system voice; a pack that is not installed reports `… voice needs a pack download`.
* **Back Chevron Tap:** Pops back to the dashboard (or replaces the route with the dashboard on a cold deep link).
* **"Confirm & Continue →" Tap:** Pops the picker and opens the unified hub. When a hub is already on the stack the picker simply returns to it, so the router never grows a duplicate console.

#### C. Technical Construction
* **Dependencies:** `flutter_bloc` (`LanguageBloc`), `flutter_tts`, `sherpa_onnx` (Piper preview), `lottie`, `lucide_icons`.
* **Architecture:** 3-layer — `LanguagePack` DTO → `LanguageBloc` (Initial → Loading → Loaded → Error) → `BlocProvider` + `BlocBuilder`.
* **Layout Rules:** Every dimension comes from `MediaQuery.sizeOf(context)`; every dynamic label sits inside an `Expanded`; **no text is ever ellipsised or clipped** — the search placeholder is painted by hand for exactly that reason.
* **Keyboard Safety:** The body is resized by the IME (`resizeToAvoidBottomInset`), the search field lives inside the scroll view and the bottom CTA only keeps a slim gap while the keyboard is open.
* **Computer Networks Concept:** **Edge Resource Management.** The selected pack decides which offline TTS model is resident in RAM and which locale the Whisper STT decodes with.

---

### Screen 1: Splash & Initial Setup Screen
* **File:** `lib/presentation/screens/splash_setup_screen.dart`
* **Role:** Device initialization, role configuration, model diagnostics, and identity assignment.

#### A. Visual Layout & UI Components
* **Background:** Clean white (`#FFFFFF`) with the dark slate squircle logo (`#1E232E`) and an emerald mic glyph (`#00875A`).
* **Call-Sign Card:** Editable input field showing auto-generated node name (e.g., `RESCUE-ALPHA-01`).
* **Role Selector Cards:** 3 selectable role options:
  1. `Transceiver (Walkie-Talkie)` [Default]: Two-way voice and text communication.
  2. `Sender Only (Scout)`: Battery-optimized transmit-only mode for field scouts.
  3. `Receiver Only (Base Station)`: Listen-only monitor for headquarters/base camps.
* **Permissions Pill Bar:** Real-time status chips for Microphone, GPS Location, and Local Network permissions.
* **Model Diagnostic Badge:** Shows 🟢 Green if `silero_vad.onnx`, Whisper STT, and Piper TTS are verified on disk.
* **CTA Button:** Full-width Forest Emerald (`#00875A`) button labeled `"Enter Tactical Comms"`.

#### B. Button Click Mechanics & Navigation
* **Role Card Tap:** Updates active role state and highlights the card border with Forest Emerald (`#00875A`).
* **"Grant Permissions" Tap:** Triggers OS native prompts for Microphone and Location permissions.
* **"Enter Tactical Comms" Tap:**
  1. Saves node call-sign, UUID hash, and selected role to local `Hive` storage.
  2. Initializes background audio and network listeners.
  3. Executes `Navigator.pushReplacementNamed(context, '/home')` to open **Screen 2**. (Splash is removed from backstack).

#### C. Technical Construction
* **Dependencies:** `permission_handler`, `hive`, `uuid`, `flutter_bloc` (`RadioBloc`).
* **Models Utilized:** Validates file existence of VAD, Whisper STT, and Piper TTS via `ModelPaths`.
* **Computer Networks Concept:** **Node Addressing & Identity Assignment.** Assigns a unique 4-byte logical node identifier used in every binary packet header.

---

### Screen 2: Home Push-To-Talk (PTT) — Sender Surface
* **File:** `lib/presentation/screens/home_ptt_screen.dart`
* **Role:** Primary operational walkie-talkie surface for real-time speech capture, transcription, and transmission. It is hosted **inside the unified comms hub** (`IndexedStack` index 0), so the hub owns the app bar, the composer and the mode dock.

#### A. Visual Layout & UI Components
* **Top Link Capsule:** Real-time link pill showing: `[📶 WiFi: 12ms | 📻 LoRa: Standby | ⏳ Queue: 0]`.
* **PTT Hero:** Large circular Forest Emerald button (`#00875A`, white mic) surrounded by a soft emerald glow, with a dotted mint meter and an animated emerald waveform strip directly beneath it.
* **Recorded Audio Card:** Clip review surface — play badge, clip duration (`0:04`), delivery state (`Ready to send` / `Sent to mesh`), a static waveform preview and the two clip actions `✕ Discard` and `Send Audio`.
* **Live Transcription HUD:** Real-time text output box displaying transcribed speech.
* **Last Received Message Card:** Displays incoming text, sender distance (`1.7 km NE`), and an instant **"Replay"** button.
* **Emergency SOS Button:** Dedicated red pulsing circular button floating above the bottom-right corner.

#### B. Button Click Mechanics & Navigation
* **PTT Button Hold (`onLongPressStart`):**
  * Haptic vibration triggers.
  * Button illuminates in solid Forest Emerald (`#00875A`) and grows with pulsing ripple rings.
  * Soundwave audio visualizer animates in real-time.
  * Microphone records 16kHz PCM audio stream via `record` package. Silero VAD monitors voice pauses.
* **PTT Button Release (`onLongPressEnd`):**
  * Audio recording halts.
  * Whisper Tiny INT8 model transcribes audio into text locally.
  * The take is staged on the **Recorded Audio card** (`Ready to send`).
  * Tap **"Send Audio"** → packetizer compresses text with zlib, attaches live GPS coordinates, computes CRC-16 checksum, and transmits packet over the active radio interface.
* **PTT Button Tap (`onTap`):** Tap-to-record gesture — the mic toggles on and off, the take is staged for review and only leaves the device when **"Send Audio"** is tapped. Holding the same button keeps the classic push-to-talk behaviour (auto-send on release).
* **Emergency SOS Tap:** Arms emergency mode. The next transmission is flagged as `Type = 0x02 (ALERT)`.
* **"Replay" Tap:** Plays back the last received message via Piper TTS audio synthesis.
* **Composer Send:** The hub composer (`Type message` + `Send ▶`) frames the typed text through the exact same `TalkTranscriptReady` path as a voice take.
* **Navigation Triggers:**
  * Tap the `🎧 RECEIVER` tab of the mode dock $\rightarrow$ swaps to **Screen 6 (Receiver Surface)** inside the same hub.
  * Tap `☰ Tactical Menu` $\rightarrow$ opens **Screen 3 (Radar)**, **Screen 4 (Comms Log)**, **Screen 5 (Radio Manager)** or **Screen 6 (Language Packs)**.
  * Tap the language line of the app bar (`Hindi · hi`) $\rightarrow$ opens **Screen 1B (Language Pack Selection)** so the working language can be changed without leaving the console.
  * Tap the Top Link Capsule $\rightarrow$ Opens **Screen 5 (Radio Manager)**.

#### C. Technical Construction
* **Dependencies:** `sherpa_onnx`, `record`, `audioplayers`, `geolocator`, `archive` (zlib), `crclib` (CRC16), `flutter_bloc` (`TalkBloc`).
* **Models Utilized:** `silero_vad.onnx` (pause detection), `sherpa-onnx-whisper-tiny` (speech-to-text).
* **Computer Networks Concepts:**
  * **Packet Framing:** Wraps payload with Magic Bytes (`0x49 0x54`), Sequence ID, Sender ID, and GPS coordinates.
  * **Application Layer Compression:** zlib compression reduces payload size by ~85% (40-60 bytes total).
  * **Error Detection:** CRC-16 polynomial appended to packet tail.
  * **Quality of Service (QoS):** Priority tagging for Normal vs Emergency SOS packets.

---

### Screen 3: Tactical Radar & Direction Screen
* **File:** `lib/presentation/screens/tactical_radar_screen.dart`
* **Role:** Directional tracking and distance calculation to locate peer senders without internet.

#### A. Visual Layout & UI Components
* **360° Rotating Compass Dial:** Military-grade radar ring showing cardinal directions (`N`, `E`, `S`, `W`) and degree markings.
* **Peer Location Blip:** Glowing emerald marker indicating the relative direction of the sender node.
* **Heading Metric HUD:** Bold telemetry readout (e.g., `1.7 KM • NORTH-EAST (45°)`).
* **Coordinates Card:** Displays My Lat/Lon vs Sender Lat/Lon, Elevation, and GPS accuracy margin (±4m).
* **View Toggle:** Button to switch between circular radar dial and offline 2D vector coordinate grid.

#### B. Button Click Mechanics & Navigation
* **Device Physical Rotation:** Internal magnetometer rotates the compass dial in real time so that North aligns with real-world orientation.
* **"Grid View" Toggle:** Switches view to an offline 2D grid plotting device nodes on an X/Y relative plane.
* **Bottom Nav PTT Tap:** Returns immediately to **Screen 2**.

#### C. Technical Construction
* **Dependencies:** `flutter_compass`, `geolocator`.
* **Models Utilized:** None (Pure mathematical and sensor-driven display).
* **Computer Networks Concepts:**
  * **Payload Deserialization:** Reads 8-byte IEEE 754 floating-point coordinates from incoming packets.
  * **Spherical Trigonometry (Haversine & Azimuth Math):** Computes great-circle surface distance and relative bearing angles between sender and receiver.

---

### Screen 4: Comms Log & Store-Retry Queue Screen
* **File:** `lib/presentation/screens/comms_log_screen.dart`
* **Role:** Transmission history, delivery acknowledgment tracking, and offline message queue inspection.

#### A. Visual Layout & UI Components
* **Summary Stats Pill:** Displays `Sent: 24 | ACK Delivered: 22 | Queued: 2 | Data Saved: 98.4%`.
* **Filter Segment:** Tabs for `All`, `SOS Alerts Only`, and `Pending Queue`.
* **Message Timeline Cards:** Tactical bubble cards showing sender call-sign, timestamp, transcribed text, and audio replay icon.
* **Status Badges:**
  * 🟢 `ACK Delivered (14ms)`
  * 🟡 `Queued in Storage (Retrying...)`
  * 🔴 `CRC Corrupted / Dropped`
* **Efficiency Metric:** Shows original raw audio size vs final compressed packet size (e.g., `48,000 B ➔ 42 B`).

#### B. Button Click Mechanics & Navigation
* **Speaker Icon Tap:** Triggers Piper TTS on demand to synthesize and speak the message text in Hindi.
* **Queued Card Tap:** Opens options to inspect retry count or tap **"Force Retransmit Now"** to bypass the backoff timer.
* **"Clear Delivered History" Tap:** Cleans up acknowledged messages from local storage while preserving queued items.

#### C. Technical Construction
* **Dependencies:** `hive`, `hive_flutter`, `audioplayers`, `sherpa_onnx`.
* **Models Utilized:** `vits-piper-hi_IN-pratham-medium` (voice synthesis on demand).
* **Computer Networks Concepts:**
  * **Stop-and-Wait ARQ (Automatic Repeat reQuest):** Manages acknowledgment timers and retransmission logic.
  * **Delay-Tolerant Networking (DTN) / Store-and-Forward:** Keeps unacknowledged packets safe in local persistent storage during link downtime.
  * **Deduplication:** Prevents duplicate message display using unique 2-byte packet sequence IDs.

---

### Screen 5: Smart Radio & Channel Manager Screen
* **File:** `lib/presentation/screens/radio_manager_screen.dart`
* **Role:** Hardware link management, peer discovery, and live demonstration controls for hackathon evaluation.

#### A. Visual Layout & UI Components
* **Interface Status HUD:** Displays active network interface details (`Interface: wlan0 | IP: 192.168.43.120 | Port: 45454`).
* **Discovered Peers List:** Lists nearby iTantra nodes detected via UDP broadcast with signal strength bars.
* **Manual IP Card:** Input field and connect button for direct unicast peering (`192.168.43.x`).
* **SIH Hackathon Live Simulators (Demo Controls):**
  * Toggle 1: `[Simulate Bad WiFi / Drop Link]`
  * Toggle 2: `[Throttle to 600 bps Low-Bitrate]`
  * Toggle 3: `[Simulate Channel Jamming / 50% Drop]`

#### B. Button Click Mechanics & Navigation
* **"Scan Peers" Tap:** Sends a UDP broadcast probe (`0x49 0x54 0xFF`) to port 45454 to discover all peers on the hotspot.
* **"Simulate Bad WiFi" Toggle ON:**
  * Intentionally shuts down the active WiFi socket.
  * Radio Manager triggers instant dynamic failover to Low-Bitrate LoRa/Virtual Radio link.
  * Screen 2 status indicator updates to yellow: `[📶 WiFi: DEAD | 📻 LoRa: ACTIVE]`.
* **"Throttle to 600 bps" Toggle ON:**
  * Restricts transmission bandwidth to 75 Bytes/second using an internal token-bucket rate limiter.
* **"Simulate Channel Jamming" Toggle ON:**
  * Drops incoming acknowledgment packets randomly to demonstrate the Store & Retry Queue in action.

#### C. Technical Construction
* **Dependencies:** `network_info_plus`, `connectivity_plus`, `dart:io` (`RawDatagramSocket`, `Socket`).
* **Models Utilized:** None (Core networking layer).
* **Computer Networks Concepts:**
  * **Multi-Homed Dynamic Link Failover:** Automatic switching between primary high-speed and fallback low-speed links.
  * **P2P UDP Broadcast Discovery:** Serverless peer discovery using `255.255.255.255`.
  * **Traffic Shaping & Rate Limiting:** Enforces strict bandwidth quotas to emulate constrained physical channels.

---

### Screen 6: Receiver Surface (Base Station)
* **File:** `lib/presentation/screens/receiver_screen.dart`
* **Role:** Listen-only base-station monitor. It is hosted **inside the unified comms hub** (`IndexedStack` index 1), so the hub owns the app bar, the mode dock and the router entry.
* **Panel Header:** Headphone badge, `Receiver` title, `Listen · Track · Reply` caption and a live `Listening` / `Standby` pill.

#### A. Visual Layout & UI Components
* **Signal Vector Card:** Haversine range (`1.7 KM`) and forward bearing (`045°`) with peer call-sign, peer coordinates, own fix and GPS accuracy chips.
* **Listen Pipeline Card:** Live bus telemetry chips — `UDP 45454`, `Magic 49 54`, `CRC-16 OK n`, `zlib On`, `Seen n`, `Dropped n`, `Peers n` — plus the auto-play toggle.
* **Quick Reply Card:** One-tap `Roger` / `Standby` acknowledgements that answer with a 6-byte ACK frame.
* **Replay Queue:** Message timeline cards with the decoded transcript, sequence ID, timestamp, range and a play/stop control.

#### B. Button Click Mechanics & Navigation
* **Mode Dock `🎤 SENDER` Tap:** Swaps the hub body back to the sender surface — same screen, same app bar, no route change.
* **Quick Reply Tap:** Sends the 6-byte reverse ACK frame over UDP 45454.
* **Auto-play Toggle Tap:** Enables or disables spoken playback of every inbound frame.

---

### Screen 5B: Offline Language Pack Manager Screen
* **File:** `lib/presentation/screens/language_manager_screen.dart`
* **Role:** Multilingual voice model management and device RAM optimization. Reached from the hub tactical menu (`☰`). The onboarding picker (Screen 1B) chooses the working language; this screen manages the packs themselves.

#### A. Visual Layout & UI Components
* **Active RAM Gauge:** Real-time memory consumption meter: `Model RAM: 110 MB / 2 GB (Optimal)`.
* **Language Grid:** 10 Indian language cards (Hindi, English, Bengali, Tamil, Telugu, Marathi, Gujarati, Punjabi, Malayalam, Kannada).
* **Status Badges:** Indicates `Active 🟢`, `Installed ⚪`, or `Download Pack 📥`.

#### B. Button Click Mechanics & Navigation
* **Language Card Tap (e.g., Hindi):**
  * Unloads existing TTS engine from memory.
  * Loads `vits-piper-hi_IN-pratham-medium` into RAM.
  * Updates active model pointer in `AppConstants`.
* **"Test Voice" Tap:** Plays an offline synthesized confirmation phrase: *"iTantra mein aapka swagat hai"*.
* **Back Button Tap:** Returns to the unified hub with the updated language preferences.

#### C. Technical Construction
* **Dependencies:** `sherpa_onnx`, `path_provider`.
* **Models Utilized:** `sherpa-onnx-whisper-tiny`, `vits-piper-hi_IN-pratham-medium`, Vosk models.
* **Computer Networks Concepts:** **Edge Resource Management.** Ensures constrained edge hardware runs smoothly by loading only active language packs into RAM.


---

### Screen 7: Critical Emergency SOS Siren Overlay
* **File:** `lib/presentation/widgets/emergency_dialog.dart`
* **Role:** High-priority, unskippable full-screen emergency alert modal.

#### A. Visual Layout & UI Components
* **Trigger:** Opens automatically whenever an incoming packet has `MsgType == 0x02 (ALERT)`.
* **Visual Alert:** Flashing Red Strobe HUD (`#DC2626` on the soft rose surface `#FEF2F2`) with animated warning icons.
* **Distress Intel Card:**
  * `🚨 SOS EMERGENCY ALERT`
  * `SENDER:` `RESCUE-TEAM-B`
  * `LOCATION:` `850m South-East (135°)`
  * `TRANSCRIBED TEXT:` *"Flood water rising fast, team stranded at sector 4"*
* **Safety Dismiss Slider:** Horizontal slide-to-confirm slider at the bottom of the screen.

#### B. Button Click Mechanics & Audio Behavior
* **Audio Action (Automatic):**
  * Forces audio output volume to 100% maximum (bypassing silent/vibrate mode).
  * Plays continuous looping emergency siren (`assets/audio/siren_alert.wav`).
  * Piper TTS repeatedly speaks the emergency distress message loudly.
* **Standard Back Button / Outside Tap:** Disabled (non-interruptible safety protocol).
* **Slide to Acknowledge:**
  * Sliding the slider fully to the right stops the siren loop.
  * Dispatches an acknowledgment packet back to the sender (`STATUS = ALERT_ACKNOWLEDGED`).
  * Dismisses the modal and navigates to **Screen 3 (Tactical Radar)** for immediate rescue guidance.

#### C. Technical Construction
* **Dependencies:** `audioplayers`, `flutter_bloc` (`AlertBloc`), `crclib`.
* **Models Utilized:** `vits-piper-hi_IN-pratham-medium` (distress voice alert synthesis).
* **Computer Networks Concepts:**
  * **Interrupt-Driven Priority Queuing (QoS Level 0):** High-priority emergency packets preempt normal application execution.
  * **Safety Acknowledgment Handshake:** Explicit delivery confirmation for mission-critical operations.

---

## 📊 3. Computer Networks Feature Matrix Across All Screens

| Computer Networks Concept | Screen Involved | Real-World Application in iTantra |
| :--- | :--- | :--- |
| **Node Addressing & Identity** | Screen 1 | UUID hash mapped to logical call-signs in the packet header. |
| **Edge Resource Management** | Screen 1B & 5B | The chosen language pack decides which TTS model stays resident in RAM. |
| **Packet Framing & Encoding** | Screen 2 | Assembles Magic Bytes, Sequence ID, GPS, and Payload into a binary packet. |
| **Application Compression (zlib)**| Screen 2 & 4 | Shrinks speech text to 40-60 bytes to fit within 600 bps links. |
| **Error Detection (CRC-16)** | Screen 2 & 4 | Mathematical checksum verifying packet integrity over noisy channels. |
| **FEC (Hamming 7,4)** | Screen 2 | Corrects single-bit transmission errors without retransmissions. |
| **Geolocation Deserialization** | Screen 3 | Unpacks IEEE 754 floating-point coordinates for distance calculation. |
| **Stop-and-Wait ARQ** | Screen 2 & 4 | Retransmission timers and ACK delivery tracking. |
| **Store & Forward / DTN** | Screen 4 | Persistent queuing ensuring zero message loss during link downtime. |
| **P2P UDP Broadcast Discovery**| Screen 5 | Serverless node discovery using `255.255.255.255:45454`. |
| **Dynamic Link Failover** | Screen 5 | Automatic traffic redirection from WiFi to LoRa when connectivity degrades. |
| **Bandwidth Throttling** | Screen 5 | Token-bucket rate limiting emulating 600 bps low-bitrate links. |
| **Priority Preemption (QoS 0)** | Screen 7 | Emergency SOS packets override standard traffic and trigger immediate alerts. |
