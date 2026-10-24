# iTantra Tactical UI Design System & Style Guide
> **Inspiration:** Dark Obsidian Minimalist with Cyber Lime / Neon Accents  
> **Aesthetic:** High-contrast, premium dark mode, ultra-clean rounded cards, OLED battery-efficient, designed for high legibility in field and emergency operations.

---

## 1. Color Palette (रंग पैलेट)

Yeh color system di gayi reference image ke exact color values se banaya gaya hai.

### Core Swatches (Color Table)

| Role / Name | HEX Code | Flutter `Color` Value | Description & Visual Placement |
| :--- | :--- | :--- | :--- |
| **Scaffold Background** | `#0B0C0E` | `const Color(0xFF0B0C0E)` | Deep Obsidian Black (OLED-friendly, pure black base). |
| **Surface Primary (Card)** | `#15171B` | `const Color(0xFF15171B)` | Floating cards, top bar capsule, bottom navigation dock. |
| **Surface Secondary** | `#1E2026` | `const Color(0xFF1E2026)` | Nested message bubbles, ticket container, inner sections. |
| **Surface Elevated / Border** | `#262933` | `const Color(0xFF262933)` | Subtle 1px borders, dividers, inactive pill backgrounds. |
| **Accent Lime (Primary CTA)** | `#BAF837` | `const Color(0xFFBAF837)` | **Hero Color.** Neon Lime green used in active pills, price tag, progress dot, center nav ring. |
| **Accent Lime Muted / Glow** | `#84CC16` | `const Color(0xFF84CC16)` | Slightly darker lime for active borders & secondary highlights. |
| **Accent Lime Subtle Glass** | `rgba(186,248,55,0.12)` | `Color(0x1FBAF837)` | Glowing backgrounds behind badges, radar blips, active chips. |
| **Emergency SOS (Alert)** | `#FF3B30` | `const Color(0xFFFF3B30)` | High-contrast tactical red for Emergency SOS alerts & sirens. |
| **Emergency SOS Subtle** | `rgba(255,59,48,0.15)` | `Color(0x26FF3B30)` | SOS alert card background glow. |
| **Text Primary (High Contrast)**| `#FFFFFF` | `const Color(0xFFFFFFFF)` | 100% Pure White for big codes (`LAX`, `CDG`), titles, and times. |
| **Text Secondary** | `#9CA0AA` | `const Color(0xFF9CA0AA)` | Medium-contrast slate silver for subtitles, departure labels. |
| **Text Muted / Inactive** | `#5C606B` | `const Color(0xFF5C606B)` | Inactive icons, timestamps, technical details. |
| **Text on Accent (Dark)** | `#0B0C0E` | `const Color(0xFF0B0C0E)` | Deep black text inside active Lime buttons (e.g. "One Way"). |

---

## 2. Typography System (फॉन्ट्स)

Reference UI ek ultra-clean, modern geometric sans-serif typeface use karti hai (jaise **Plus Jakarta Sans**, **Inter**, ya **SF Pro Display**). 

### Recommended Google Fonts for Flutter:
* **Primary Font:** `GoogleFonts.plusJakartaSans()` ya `GoogleFonts.inter()`
* **Technical / Monospace Numbers:** `GoogleFonts.jetBrainsMono()` (GPS coordinates, Packet Bytes, Bitrates ke liye).

### Typography Scale Table

| Style Name | Size | Weight | Letter Spacing | Example in App |
| :--- | :--- | :--- | :--- | :--- |
| **Display Station Code** | `26px` - `30px` | `FontWeight.w700` (Bold) | `1.2px` | Device Nodes (`RESCUE-A`, `BASE-01`) |
| **Section Title / Headings** | `18px` - `20px` | `FontWeight.w600` (SemiBold)| `-0.2px` | Screen Titles, Card Headers |
| **Metric Value (Lime)** | `16px` - `18px` | `FontWeight.w700` (Bold) | `0.0px` | Distance (`1.7 KM`), Latency (`12 ms`) |
| **Body Primary** | `14px` - `15px` | `FontWeight.w500` (Medium) | `0.0px` | Transcribed voice text, message body |
| **Label / Pill Text** | `12px` - `13px` | `FontWeight.w600` (SemiBold)| `0.3px` | Active Pill ("WiFi", "One Way", "PTT") |
| **Micro / Subtitle** | `11px` - `12px` | `FontWeight.w400` (Regular) | `0.2px` | Coordinates, Timestamps, Byte count |

---

## 3. UI Component Mapping (इस टेम्पलेट को iTantra में कैसे बदलें)

Reference image ke flight-booking elements humare emergency walkie-talkie app mein perfectly fit hote hain:

```
Reference UI (Image)                 ➔   iTantra App Mapping
─────────────────────────────────────────────────────────────────────────────
Top Header (Profile & Location)      ➔   Device Call-Sign & GPS Status (e.g., "ALPHA-01 • 28.61° N")
"One Way / Round Trip" Capsule Pills ➔   Radio Link Selector ("WiFi" / "LoRa 600bps")
"ICH ➔ LAX" Flight Route Card        ➔   "SENDER ➔ RECEIVER" P2P Transmission Card
Dotted Flight Track with Airplane    ➔   Signal Strength / Waveform / Packet Transit Line
Bottom Floating Nav with Ring Button ➔   Floating Tactical Dock with Central PTT Button Ring
Green Price Tag "$499"               ➔   Neon Green Status ("1.7 KM" / "ACK CONFIRMED")
```

### Component Details:

### A. Rounded Card Surface (The "Flight Ticket" Style)
* **Background:** `#15171B`
* **Border:** `1px solid #262933`
* **Border Radius:** `BorderRadius.circular(24.0)`
* **Inner Padding:** `18px` to `20px`
* **Shadow:** Soft dark drop shadow (`BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: Offset(0, 8))`).

### B. Segmented Link Switcher (Pill Style)
* **Container:** Deep dark capsule with `BorderRadius.circular(999)`.
* **Inactive State:** Background transparent, text `#9CA0AA`.
* **Active State:** Solid Neon Lime (`#BAF837`), text `#0B0C0E` (Bold).

### C. The Central PTT (Push-To-Talk) Action
* Reference image ke bottom navigation mein center icon par **Neon Lime Ring** bani hui hai.
* iTantra mein center button humara **Walkie-Talkie PTT Button** banega:
  * Rest state: `#1E2026` background, surrounded by glowing Neon Lime border (`#BAF837`).
  * Pressed / Speaking state: Button solid `#BAF837` fill ho jayega with vibrating/pulsing Lime soundwave!

### D. Transmission Progress Line
* Flight UI mein airport codes ke beech dotted green track bana hai.
* iTantra mein yeh:
  * **Sender Node (`NODE-A`)** se **Receiver Node (`NODE-B`)** ke beech signal flow dikhayega.
  * Packets transit hote waqt chhota green indicator dot dot-by-dot aage move hoga.

---

## 4. Ready-to-Copy Flutter Code Blueprint

Jab aap code implement karenge, toh aap direct neeche diye gaye classes ko use kar sakte hain:

```dart
import 'package:flutter/material.dart';

/// iTantra Tactical Cyber-Lime Palette
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0B0C0E);
  static const Color surfacePrimary = Color(0xFF15171B);
  static const Color surfaceSecondary = Color(0xFF1E2026);
  static const Color surfaceBorder = Color(0xFF262933);

  // Hero Neon Accents
  static const Color accentLime = Color(0xFFBAF837);
  static const Color accentLimeMuted = Color(0xFF84CC16);
  static const Color accentLimeGlow = Color(0x1FBAF837);

  // Emergency SOS Accents
  static const Color alertRed = Color(0xFFFF3B30);
  static const Color alertRedGlow = Color(0x26FF3B30);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA0AA);
  static const Color textMuted = Color(0xFF5C606B);
  static const Color textOnAccent = Color(0xFF0B0C0E);
}

/// ThemeData generator for iTantra
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'PlusJakartaSans',
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surfacePrimary,
        primary: AppColors.accentLime,
        secondary: AppColors.accentLimeMuted,
        error: AppColors.alertRed,
        onPrimary: AppColors.textOnAccent,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.0),
        ),
      ),
    );
  }
}
```

---

## 5. Summary Guidelines for App Screens

1. **Never use bright white cards:** Cards humesha deep dark charcoal (`#15171B`) rahenge.
2. **Neon Lime sparingly use karein:** Lime `#BAF837` ko sirf active triggers, primary CTAs, delivery confirmations, aur direction metrics par lagayein taaki visual hierarchy bohot sharp rahe.
3. **Emergency SOS Exception:** Emergency alerts aur sirens ke liye Neon Red (`#FF3B30`) poore UI mein highest visual priority rakhega.
4. **Curved Edges:** Har container aur card mein kam se kam `20px` se `28px` ka smooth corner radius rahega.
