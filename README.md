# PivotStream iOS

RSVP (Rapid Serial Visual Presentation) reader for iOS. Words appear one at a time, aligned at the **Optimal Recognition Point** — the character your eye naturally anchors on — so you read faster without moving your eyes.

A native Swift port of the [PivotStream web app](https://github.com/diegoandrade/pivotstream).

---

## Features

- **RSVP playback** with adjustable speed (100–1600 WPM) and automatic speed ramp
- **ORP alignment** — each word is split into left / pivot / right with the pivot highlighted in red
- **EPUB support** — parses container, OPF manifest, spine, and TOC (EPUB3 nav or EPUB2 NCX)
- **PDF support** — extracts text and auto-detects section headings (numeric, roman numeral, alphabetic)
- **Chapter navigation** — jump to any chapter or section mid-read
- **Share Extension** — share text or a webpage from any app directly into PivotStream
- **Pause multipliers** — longer pauses after `.!?`, `;:`, and `,` for natural rhythm
- No third-party dependencies — ZIP decompression uses `zlib` directly

---

## Requirements

- Xcode 16+
- iOS 17+
- Swift 5.9+

---

## Getting Started

```bash
open PivotStream/PivotStream.xcodeproj
```

1. Select your **Development Team** in **Signing & Capabilities**
2. Choose a simulator or connected device
3. Press **⌘R**

---

## Project Structure

```
PivotStream/
└── PivotStream/                    ← source root (auto-synced by Xcode)
    ├── PivotStreamApp.swift        ← @main, deep link handling
    ├── ContentView.swift           ← root layout, sheet coordination
    ├── Models/
    │   ├── Token.swift             ← word + ORP index + pause multiplier
    │   └── Chapter.swift          ← chapter/section with token start index
    ├── Engine/
    │   └── RSVPEngine.swift       ← async playback loop, speed ramp, seek/jump
    ├── Parsers/
    │   ├── TextParser.swift       ← tokenization + ORP calculation
    │   ├── ZipReader.swift        ← pure Swift ZIP reader via zlib
    │   ├── EPUBParser.swift       ← EPUB → text + chapters
    │   └── PDFParser.swift        ← PDF → text + sections (PDFKit)
    ├── ViewModels/
    │   └── ReaderViewModel.swift  ← app state, wraps RSVPEngine
    ├── Views/
    │   ├── RSVPView.swift         ← RSVP display with ORP pivot
    │   ├── ControlsView.swift     ← WPM slider + playback controls
    │   ├── InputPanelView.swift   ← text input + file import
    │   ├── ChaptersView.swift     ← chapter navigation
    │   └── Theme.swift            ← color tokens
    └── Books/
        ├── austen-pride-and-prejudice-illustrations.epub
        └── sample.pdf
ShareExtension/
    └── ShareViewController.swift  ← shares text/URLs from other apps
```

---

## How ORP Works

The Optimal Recognition Point is computed from word length:

| Word length | ORP index |
|---|---|
| 1 | 0 |
| 2–5 | 1 |
| 6–9 | 2 |
| 10–13 | 3 |
| 14+ | 4 |

Pause multipliers slow display time after punctuation: `.!?` → ×3.0, `:;` → ×2.8, `,` → ×2.4. Long words add a further bonus.

---

## Share Extension Setup

The Share Extension is included but requires one-time Xcode configuration:

1. In the **PivotStream** target → **Info** → **URL Types** → add scheme `pivotstream`
2. In both targets → **Signing & Capabilities** → **App Groups** → add `group.com.yourname.pivotstream`

See [SETUP.md](SETUP.md) for full step-by-step instructions.

---

## Web App Reference

| Python / JS | Swift |
|---|---|
| `_split_token()` | `TextParser.splitToken(_:)` |
| `_extract_epub_data()` | `EPUBParser.parse(url:)` |
| `_extract_pdf_sections()` | `PDFParser.detectSections(in:)` |
| JS playback loop | `RSVPEngine.launchPlaybackTask()` |
| `showToken()` | `RSVPView` |
