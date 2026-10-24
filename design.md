# iTantra Neural Voice UI Design System & Style Guide (v2.0)
> **Design Theme:** Clean Light Neural UI with Forest Emerald Accents & Pastel Language Chips  
> **Aesthetic:** Modern, ultra-clean light mode, high legibility, soft rounded geometry, accessible Indic typography, designed for edge neural voice and tactical mesh walkie-talkie communication.  
> **Legacy Version:** The previous dark tactical OLED design system is preserved in [`design_v1_dark.md`](file:///d:/itantra/design_v1_dark.md).

---

## 1. Executive Summary & Visual Philosophy

iTantra v2.0 transitions to an ultra-modern, high-clarity **Light Neural Design System** modeled after enterprise-grade consumer hardware and tactical emergency tools. The interface pairs a crisp white/soft slate scaffold with a signature **Forest Emerald Green** primary brand identity, complemented by soft pastel status chips, gentle micro-borders, and high-visibility alert cards.

### Core Visual Principles:
1. **Light, Open & Crisp:** Clean white (`#FFFFFF`) and slate-50 (`#F8FAFC`) surfaces ensure effortless readability in direct daylight and field scenarios.
2. **Signature Forest Emerald Accent:** A rich, calming, yet authoritative emerald green (`#00875A` / `#059669`) serves as the hero action color for Push-To-Talk (PTT), active tabs, and primary CTAs.
3. **Indic Multi-Language First:** Tailored avatar chips with individual pastel color identities for 10 Indian languages (Hindi, Gujarati, Marathi, Kannada, Malayalam, Tamil, Telugu, Odia, Bengali, Punjabi).
4. **Instant Action Clarity:** Large circular tactile buttons, high-contrast bilingual alert cards (Hindi + English translations), and intuitive audio waveform previews.

---

## 2. Complete Color Palette (रंग पैलेट)

Di gayi reference images ke exact hex codes aur semantic roles:

### Core Palette Table

| Role / Token Name | HEX Code | Flutter `Color` Value | Visual Usage & Context |
| :--- | :--- | :--- | :--- |
| **Scaffold Background** | `#FFFFFF` | `const Color(0xFFFFFFFF)` | Main screen background for onboarding, language selection, and feeds. |
| **Surface Secondary / Fill** | `#F8FAFC` | `const Color(0xFFF8FAFC)` | Search inputs, bottom message box background, subtle card fills. |
| **Surface Border** | `#E2E8F0` | `const Color(0xFFE2E8F0)` | 1px border for unselected cards, search bar, and message inputs. |
| **Surface Border Subtle** | `#F1F5F9` | `const Color(0xFFF1F5F9)` | Subtle dividers, bottom nav top border, feed card outline. |
| **Primary Emerald (Hero CTA)** | `#00875A` | `const Color(0xFF00875A)` | **Signature Brand Color.** Primary button fill, big PTT circle, active tab indicator, confirm CTA. |
| **Primary Emerald Vibrant** | `#059669` | `const Color(0xFF059669)` | Active checkmark circle, active badges, live node icons. |
| **Emerald Subtle Glow** | `rgba(0,135,90,0.18)` | `Color(0x2E00875A)` | Soft diffused drop shadow beneath hero PTT button & primary CTA. |
| **Emerald Mint Tint** | `#ECFDF5` | `const Color(0xFFECFDF5)` | Background for `• Mesh Active`, `• Node Live`, and feature pill chips. |
| **Emerald Mint Border** | `#A7F3D0` | `const Color(0xFFA7F3D0)` | Border for active language card, replay alert button, and audio progress bars. |
| **Emerald Avatar Soft** | `#DCFCE7` | `const Color(0xFFDCFCE7)` | Background for play buttons, Hindi `HI` badge, and transmission badges. |
| **Waveform Active Bars** | `#00875A` | `const Color(0xFF00875A)` | Live recording vertical waveform bars. |
| **Waveform Preview Bars** | `#A7F3D0` | `const Color(0xFFA7F3D0)` | Recorded audio preview bar & message feed audio waveforms. |

---

### Emergency Alert Palette (आपत्कालीन अलर्ट)

| Role / Token Name | HEX Code | Flutter `Color` Value | Visual Usage & Context |
| :--- | :--- | :--- | :--- |
| **Alert Red (Critical)** | `#DC2626` | `const Color(0xFFDC2626)` | `⚠️ CRITICAL ALERT` headline, high-priority button text. |
| **Alert Red Accent** | `#EF4444` | `const Color(0xFFEF4444)` | Warning icons, urgent badge pulses. |
| **Alert Surface Soft (Rose)** | `#FEF2F2` | `const Color(0xFFFEF2F2)` | High-priority SOS alert card background. |
| **Alert Border Soft** | `#FECACA` | `const Color(0xFFFECACA)` | 1px border around critical alert cards. |
| **Alert Button Background** | `#FFF5F5` | `const Color(0xFFFFF5F5)` | Background for "High-Priority Audio" button. |
| **Alert Button Border** | `#FCA5A5` | `const Color(0xFFFCA5A5)` | Border for "High-Priority Audio" button. |

---

### Typography & Neutral Grayscale

| Role / Token Name | HEX Code | Flutter `Color` Value | Visual Usage & Context |
| :--- | :--- | :--- | :--- |
| **Text Primary (Dark Slate)** | `#0F172A` | `const Color(0xFF0F172A)` | Screen titles, app name `iTantra`, native Indic script text. |
| **Text Secondary (Slate)** | `#64748B` | `const Color(0xFF64748B)` | Subtitles ("Tactical Audio & Alerts", "0:00 • Ready to send", English translations). |
| **Text Muted / Placeholder** | `#94A3B8` | `const Color(0xFF94A3B8)` | Inactive icons, timestamps ("10:28", "Just now"), search hints. |
| **Text on Primary** | `#FFFFFF` | `const Color(0xFFFFFFFF)` | Pure white text on emerald buttons and mic icon. |
| **App Icon Squircle Base** | `#1E232E` | `const Color(0xFF1E232E)` | Dark slate squircle background for the iTantra app launcher icon. |

---

### Indic Language Avatar Pastels (भाषा बैज पैलेट)

Har Indian language ke liye unique, pleasant pastel color pair banaya gaya hai taaki UI visually rich aur recognizable rahe:

| Language | Code | Background HEX | Background `Color` | Text HEX | Text `Color` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hindi (हिंदी)** | `HI` | `#DCFCE7` | `const Color(0xFFDCFCE7)` | `#059669` | `const Color(0xFF059669)` |
| **Gujarati (ગુજરાતી)** | `GU` | `#DBEAFE` | `const Color(0xFFDBEAFE)` | `#1D4ED8` | `const Color(0xFF1D4ED8)` |
| **Marathi (मराठी)** | `MR` | `#FCE7F3` | `const Color(0xFFFCE7F3)` | `#BE185D` | `const Color(0xFFBE185D)` |
| **Kannada (ಕನ್ನಡ)** | `KN` | `#FEF3C7` | `const Color(0xFFFEF3C7)` | `#B45309` | `const Color(0xFFB45309)` |
| **Malayalam (മലയാളം)**| `ML` | `#EDE9FE` | `const Color(0xFFEDE9FE)` | `#6D28D9` | `const Color(0xFF6D28D9)` |
| **Tamil (தமிழ்)** | `TA` | `#FFEDD5` | `const Color(0xFFFFEDD5)` | `#C2410C` | `const Color(0xFFC2410C)` |
| **Telugu (తెలుగు)** | `TE` | `#CCFBF1` | `const Color(0xFFCCFBF1)` | `#0F766E` | `const Color(0xFF0F766E)` |
| **Audio Preview Icon** | `🔊` | `#DBEAFE` | `const Color(0xFFDBEAFE)` | `#60A5FA` | `const Color(0xFF60A5FA)` |

---

## 3. Typography System (फॉन्ट्स एवं टाइपोग्राफी)

The UI utilizes a geometric, human-centric sans-serif typeface family with dedicated fallback support for Indic scripts.

### Recommended Font Stacks:
* **Primary Latin & UI Text:** `GoogleFonts.plusJakartaSans()` ya `GoogleFonts.inter()`
* **Indic Scripts Fallbacks:**
  * Devanagari (Hindi, Marathi): `GoogleFonts.notoSansDevanagari()`
  * Gujarati: `GoogleFonts.notoSansGujarati()`
  * Kannada: `GoogleFonts.notoSansKannada()`
  * Malayalam: `GoogleFonts.notoSansMalayalam()`
  * Tamil: `GoogleFonts.notoSansTamil()`
  * Telugu: `GoogleFonts.notoSansTelugu()`
  * Odia: `GoogleFonts.notoSansOriya()`

### Typography Scale Table

| Style Token | Font Size | Weight | Line Height | Letter Spacing | Example Placement in App |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Brand Title** | `30px` - `34px` | `FontWeight.w800` | `1.2` | `-0.5px` | "iTantra" on splash & onboarding screen |
| **Screen Headline** | `22px` - `24px` | `FontWeight.w800` | `1.25` | `-0.3px` | "Select Working Language", "Incoming Feed" |
| **Hero Action Caption** | `13px` - `14px` | `FontWeight.w700` | `1.3` | `1.5px` | "PUSH TO TALK" uppercase subtitle |
| **Card Primary Title** | `15px` - `16px` | `FontWeight.w700` | `1.35` | `0.0px` | "हिंदी", "Recorded Audio", Broadcast Quote |
| **Card Subtitle / Body** | `13px` - `14px` | `FontWeight.w500` | `1.4` | `0.0px` | "0:00 • Ready to send", "Station 2 verified..." |
| **English Translation / Meta**| `12px` - `13px` | `FontWeight.w400` | `1.4` | `0.1px` | *Italic* "Warn! Immediate assistance..." |
| **Pill / Status Badge** | `12px` - `13px` | `FontWeight.w600` | `1.0` | `0.2px` | "• Mesh Active", "100% Offline" |
| **Button CTA Text** | `16px` | `FontWeight.w700` | `1.2` | `0.2px` | "Get Started →", "Confirm & Continue →" |
| **Secondary Button** | `13px` - `14px` | `FontWeight.w600` | `1.2` | `0.1px` | "✕ Discard", "Send Audio", "Replay Alert" |
| **Timestamp / Micro** | `11px` - `12px` | `FontWeight.w500` | `1.2` | `0.2px` | "10:28", "Just now", "Ultra-low Latency" |

---

## 4. UI Component & Widget Blueprint (विजेट विनिर्देश)

Reference images ke anusaar banaye gaye 10 pramukh UI widgets:

### A. Top Identity Bar (`AppIdentityBar`)
* **Layout:** Horizontal row containing:
  1. Back Chevron `<` (`24px`, `#0F172A`).
  2. Dark Squircle App Icon (`36x36px`, rounded `10px`, background `#1E232E`, inner mic `#00875A`).
  3. Vertical column with:
     * App Title: `iTantra` (`17px`, `FontWeight.w800`, `#0F172A`).
     * Subtitle: `हिंदी (Hindi)` ya `Tactical Audio & Alerts` (`12px`, `#64748B`).
  4. Status Badge Capsule on the right:
     * `• Mesh Active` (`#ECFDF5` background, `#059669` dot and text, rounded `999`).

### B. Language Selection Tile (`LanguageTile`)
* **Unselected State:**
  * Background: Pure white `#FFFFFF`
  * Border: `1px solid #E2E8F0`
  * Border Radius: `16px`
  * Avatar: Pastel box (`40x40px`, rounded `10px`) with language code (e.g., `GU`, `MR`)
  * Native Title + English Subtitle
  * Trailing: Soft sky blue speaker preview icon (`#60A5FA`) + Radio unselected circle (`#D1D5DB`)
* **Selected State (e.g. Hindi):**
  * Background: Mint Tint `#F0FDF4`
  * Border: `1.5px solid #86EFAC`
  * Avatar: Pale emerald `#DCFCE7` with green text `HI` (`#059669`)
  * Trailing: Speaker icon + Solid emerald circle (`#059669`) with white checkmark `✓`

### C. Hero Push-To-Talk Button (`PttHeroButton`)
* **Visual States:**
  1. **Idle State:**
     * Diameter: `130px`
     * Background: Solid Forest Emerald `#00875A`
     * Icon: Crisp white microphone (`42px`, `Icons.mic` or SVG)
     * Shadow: `BoxShadow(color: Color(0x3300875A), blurRadius: 24, offset: Offset(0, 10))`
     * Dotted Meter: Horizontal dotted line beneath button in pale mint `#A7F3D0`
     * Caption: *"Hold mic to record, release to preview"* (`13px`, `#64748B`)
  2. **Recording State:**
     * Button expands with smooth spring animation (`140px`)
     * Animated pulsating ripple rings around button (`Color(0x1F00875A)`)
     * Dynamic Waveform Strip: Active vertical bars (`#00875A`) moving dynamically with voice volume.

### D. Recorded Audio Preview Card (`RecordedAudioCard`)
* **Container:** White card `#FFFFFF`, rounded `20px`, border `1px solid #E5E7EB`, padding `16px`.
* **Audio Track Header:**
  * Play/Pause Circle: Soft mint circle `#DCFCE7` with emerald play triangle `#00875A`.
  * Title: `Recorded Audio` (`15px`, bold `#0F172A`).
  * Subtitle: `0:00 • Ready to send` (`12px`, `#64748B`).
* **Waveform Preview:** Symmetrical rounded frequency bars in sage mint `#A7F3D0`.
* **Action Buttons Row:**
  * **Discard Button:** Light white container, border `1px solid #E5E7EB`, text `✕ Discard` (`#475569`).
  * **Send Audio Button:** Solid Forest Emerald `#00875A`, white text `📥 Send Audio` (with send icon).

### E. Comms Message Composer (`CommsComposerBar`)
* **Container:** Rounded pill/capsule input bar `#F8FAFC`, border `1px solid #E2E8F0`.
* **Hint Text:** `"Type message in Hindi or En..."` in `#94A3B8`.
* **Integrated Action:** Solid emerald capsule button `"Send ▶"` on the right end (`#00875A`, white bold text).

### F. Critical Emergency Alert Card (`CriticalAlertBanner`)
* **Background:** Soft rose blush `#FEF2F2`.
* **Border:** `1px solid #FECACA`.
* **Border Radius:** `20px`.
* **Header Row:**
  * Tag: `⚠️ CRITICAL ALERT` in bold vivid red (`#DC2626`).
  * Timestamp: `Just now` (`#94A3B8`).
* **Content:**
  * Primary Hindi Alert: `"सावधान! गेट नंबर 4 पर तुरंत सहायता की आवश्यकता है!"` (`16px`, bold `#0F172A`).
  * English Translation: `Warn! Immediate assistance required at Gate 4!` (`13px`, italic slate `#64748B`).
* **Dual Action Buttons:**
  1. `🔊 High-Priority Audio`: White/pink background `#FFF5F5`, border `1px solid #FCA5A5`, text `#DC2626`.
  2. `🔄 Replay Alert`: White background `#FFFFFF`, border `1px solid #A7F3D0`, text `#00875A`.

### G. Incoming Transmission Feed Card (`IncomingTransmissionCard`)
* **Container:** Pure white `#FFFFFF`, border `1px solid #F1F5F9`, rounded `18px`, padding `16px`.
* **Sender Meta Row:**
  * Squircle badge: Mint `#DCFCE7` with walkie-talkie / device icon.
  * Node Name: `Pixel 7a • Patrol Team` or `Mesh Node 00 • Medical` (`13px`, bold `#00875A`).
  * Timestamp: `10:28` / `10:29` (`#94A3B8`).
* **Message Body:**
  * Native text (e.g. Odia, Hindi, English).
  * Sub-text translation in italics.
* **Inline Waveform Audio Player:**
  * Mint play button + sage green waveform + duration label (`0:02`, `0:04`).
* **Quick Expansion Action:** `+ Audio Translation` in emerald green `#00875A`.

### H. Bottom Tactical Navigation Dock (`BottomTacticalDock`)
* **Background:** Pure white `#FFFFFF`, border-top `1px solid #F1F5F9`.
* **Height:** `70px` (plus safe area padding).
* **Two Tabs:**
  1. **SENDER:** Active state shows green mic icon, green uppercase label `SENDER` (`#00875A`), and a **solid emerald indicator line** (`2.5px` height, `#00875A`) pinned at the top edge of the tab.
  2. **RECEIVER:** Inactive state shows muted slate satellite dish icon and slate uppercase label `RECEIVER` (`#94A3B8`).

---

## 5. Screen-by-Screen Flow & Layout Architecture

```
[Screen 1: Splash / Onboarding]
   │
   ├── App Squircle Icon (Dark slate with emerald mic)
   ├── "iTantra" Brand Title
   ├── "Local Neural Speech & Edge Walkie-Talkie"
   ├── Feature Badges ("10 Indian Languages" | "• 100% Offline")
   ├── "Ultra-low Latency"
   └── Big Hero CTA Button: "Get Started →"
   │
   ▼
[Screen 2: Language Selection]
   │
   ├── Title: "Select Working Language"
   ├── Search Bar: "Search 10 languages..."
   ├── List of 10 Indian Languages with Pastel Code Chips
   │   ├── [Selected] Hindi (Mint background, green checkmark, speaker)
   │   └── [Unselected] Gujarati, Marathi, Kannada, Malayalam, Tamil...
   └── Bottom CTA Button: "Confirm & Continue →"
   │
   ▼
[Screen 3 & 5: Sender (Push-To-Talk Ready & Recording Preview)]
   │
   ├── Top Identity Bar: iTantra • हिंदी (Hindi) • [• Mesh Active]
   ├── [Ready State] "PUSH TO TALK" ➔ Large Emerald PTT Mic Button ➔ Dotted Meter
   ├── [Hold-To-Talk State] Pulsing Emerald Waveform
   ├── [Preview State] Recorded Audio Card (Play, Waveform, Discard, Send)
   ├── Message Input Field with "Send ▶" capsule
   └── Bottom Dock: [SENDER (Active)] | [RECEIVER (Inactive)]
   │
   ▼
[Screen 4: Receiver (Incoming Tactical Feed)]
   │
   ├── Top Identity Bar: iTantra • Tactical Audio & Alerts • [• Mesh Active]
   ├── Title: "Incoming Feed" • "2 received transmissions" • [• Node Live]
   ├── [Card 1] CRITICAL ALERT (Soft Rose banner, Hindi + English, 2 CTA buttons)
   ├── [Card 2] Patrol Team Voice Message (Node, Waveform, Play, 0:02)
   ├── [Card 3] Medical Emergency Voice Message (Odia script + Translation)
   └── Bottom Dock: [SENDER (Inactive)] | [RECEIVER (Active)]
```

---

## 6. Ready-to-Copy Flutter Code Blueprint

Neeche diya gaya code directly aapke Flutter project (`lib/core/theme/`) aur presentation layer ke liye production-ready hai:

```dart
import 'package:flutter/material.dart';

/// iTantra Light Neural Color Tokens
class AppColors {
  AppColors._();

  // Background & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceBorder = Color(0xFFE2E8F0);
  static const Color surfaceBorderSubtle = Color(0xFFF1F5F9);

  // Hero Brand Emerald
  static const Color primaryEmerald = Color(0xFF00875A);
  static const Color primaryEmeraldVibrant = Color(0xFF059669);
  static const Color primaryEmeraldDark = Color(0xFF065F46);
  static const Color emeraldMintTint = Color(0xFFECFDF5);
  static const Color emeraldMintBorder = Color(0xFFA7F3D0);
  static const Color emeraldAvatarBg = Color(0xFFDCFCE7);
  static const Color waveformActive = Color(0xFF00875A);
  static const Color waveformPreview = Color(0xFFA7F3D0);

  // Emergency Alert Red Tokens
  static const Color alertRed = Color(0xFFDC2626);
  static const Color alertRedAccent = Color(0xFFEF4444);
  static const Color alertRedBg = Color(0xFFFEF2F2);
  static const Color alertRedBorder = Color(0xFFFECACA);
  static const Color alertBtnBg = Color(0xFFFFF5F5);
  static const Color alertBtnBorder = Color(0xFFFCA5A5);

  // Neutral Typography & Grays
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Icon Launcher Base
  static const Color iconSquircleBg = Color(0xFF1E232E);

  // Language Avatar Pastel Swatches
  static const Color langHindiBg = Color(0xFFDCFCE7);
  static const Color langHindiText = Color(0xFF059669);

  static const Color langGujaratiBg = Color(0xFFDBEAFE);
  static const Color langGujaratiText = Color(0xFF1D4ED8);

  static const Color langMarathiBg = Color(0xFFFCE7F3);
  static const Color langMarathiText = Color(0xFFBE185D);

  static const Color langKannadaBg = Color(0xFFFEF3C7);
  static const Color langKannadaText = Color(0xFFB45309);

  static const Color langMalayalamBg = Color(0xFFEDE9FE);
  static const Color langMalayalamText = Color(0xFF6D28D9);

  static const Color langTamilBg = Color(0xFFFFEDD5);
  static const Color langTamilText = Color(0xFFC2410C);

  static const Color langTeluguBg = Color(0xFFCCFBF1);
  static const Color langTeluguText = Color(0xFF0F766E);

  static const Color audioPreviewIcon = Color(0xFF60A5FA);
}

/// iTantra Material 3 Light Theme
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'PlusJakartaSans',
      colorScheme: const ColorScheme.light(
        surface: AppColors.background,
        primary: AppColors.primaryEmerald,
        secondary: AppColors.primaryEmeraldVibrant,
        error: AppColors.alertRed,
        onPrimary: AppColors.textWhite,
        onSurface: AppColors.textPrimary,
        outline: AppColors.surfaceBorder,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: AppColors.textWhite,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
```

---

## 7. Reusable Custom UI Widgets (Flutter Blueprints)

### A. The Hero Push-To-Talk Button (`PttHeroButton`)
```dart
class PttHeroButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const PttHeroButton({
    super.key,
    required this.isRecording,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: onHoldEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isRecording ? 140 : 126,
        height: isRecording ? 140 : 126,
        decoration: BoxDecoration(
          color: AppColors.primaryEmerald,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryEmerald.withOpacity(isRecording ? 0.45 : 0.25),
              blurRadius: isRecording ? 32 : 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 46,
          ),
        ),
      ),
    );
  }
}
```

### B. Recorded Audio Preview Card (`RecordedAudioCard`)
```dart
class RecordedAudioCard extends StatelessWidget {
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  const RecordedAudioCard({
    super.key,
    required this.onDiscard,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.emeraldAvatarBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryEmerald, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recorded Audio',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    '0:00 • Ready to send',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Waveform preview mockup
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                24,
                (i) => Container(
                  width: 3,
                  height: (i % 5 + 2) * 3.5,
                  decoration: BoxDecoration(
                    color: AppColors.waveformPreview,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Discard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### C. Critical Emergency Alert Banner (`CriticalAlertCard`)
```dart
class CriticalAlertCard extends StatelessWidget {
  final String nativeAlert;
  final String englishTranslation;
  final VoidCallback onPlayHighPriority;
  final VoidCallback onReplay;

  const CriticalAlertCard({
    super.key,
    required this.nativeAlert,
    required this.englishTranslation,
    required this.onPlayHighPriority,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.alertRedBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.alertRedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'CRITICAL ALERT',
                    style: TextStyle(
                      color: AppColors.alertRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                'Just now',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"$nativeAlert"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            englishTranslation,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPlayHighPriority,
                  icon: const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.alertRed),
                  label: const Text('High-Priority Audio', style: TextStyle(fontSize: 12, color: AppColors.alertRed)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.alertBtnBg,
                    side: const BorderSide(color: AppColors.alertBtnBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay_rounded, size: 16, color: AppColors.primaryEmerald),
                  label: const Text('Replay Alert', style: TextStyle(fontSize: 12, color: AppColors.primaryEmerald)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.emeraldMintBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### D. Bottom Tactical Dock (`BottomTacticalDock`)
```dart
class BottomTacticalDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const BottomTacticalDock({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceBorderSubtle, width: 1.0)),
      ),
      child: Row(
        children: [
          _buildTabItem(
            index: 0,
            label: 'SENDER',
            icon: Icons.mic_none_rounded,
            isSelected: currentIndex == 0,
          ),
          _buildTabItem(
            index: 1,
            label: 'RECEIVER',
            icon: Icons.settings_input_antenna_rounded,
            isSelected: currentIndex == 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.primaryEmerald : AppColors.textMuted,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isSelected ? AppColors.primaryEmerald : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 8. Summary Checklist for Frontend Implementation

1. **Scaffold & Backgrounds:** Ensure scaffold backgrounds are pure white (`#FFFFFF`) with secondary inputs set to slate-50 (`#F8FAFC`).
2. **Primary CTAs:** All primary action buttons must use Forest Emerald (`#00875A`) with pure white text and an `18px` border radius.
3. **Indic Multi-Language Support:** Configure fallback font families (`Noto Sans Devanagari`, `Noto Sans Tamil`, etc.) so that all 10 Indian scripts render crisply without font clipping.
4. **Emergency Visibility:** Critical alerts use the dedicated soft-rose card (`#FEF2F2`) with red borders and dual action buttons.
5. **Preservation:** The legacy dark obsidian style is safely kept in [`design_v1_dark.md`](file:///d:/itantra/design_v1_dark.md) for optional dark-mode toggling in future versions.
