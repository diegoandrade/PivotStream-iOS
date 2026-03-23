# PivotStream iOS — Setup Guide

## Open the Project

```bash
open PivotStream/PivotStream.xcodeproj
```

Set your **Development Team** in **Signing & Capabilities**, then press **⌘R** to build and run.

---

## File Structure

```
PivotStream/
└── PivotStream/                        ← source root (synced by Xcode)
    ├── PivotStreamApp.swift            ← @main entry point
    ├── ContentView.swift               ← root layout + sheet coordination
    ├── Assets.xcassets/                ← AccentColor (red), AppIcon
    ├── Models/
    │   ├── Token.swift                 ← word + ORP index + pause multiplier
    │   └── Chapter.swift              ← chapter/section with token start index
    ├── Engine/
    │   └── RSVPEngine.swift           ← core playback: timing loop, ramp, seek
    ├── Parsers/
    │   ├── TextParser.swift           ← tokenization + ORP calculation
    │   ├── ZipReader.swift            ← ZIP extraction via zlib (used by EPUB)
    │   ├── EPUBParser.swift           ← EPUB → text + chapters
    │   └── PDFParser.swift            ← PDF → text + sections (PDFKit)
    ├── ViewModels/
    │   └── ReaderViewModel.swift      ← app state, wraps RSVPEngine
    └── Views/
        ├── RSVPView.swift             ← RSVP focus window with ORP alignment
        ├── ControlsView.swift         ← WPM slider + playback buttons
        ├── InputPanelView.swift       ← text input + EPUB/PDF file import
        ├── ChaptersView.swift         ← chapter/section navigation list
        └── Theme.swift                ← Color extensions (orpAccent, readerBackground)
```

---

## Add the Share Extension (optional)

Allows users to share text or a webpage directly into PivotStream from any app.

### 1. Add the target

1. **File → New → Target → iOS → Share Extension**
2. Name it `ShareExtension`
3. When prompted "Activate scheme?" click **Cancel**
4. Delete the auto-generated `ShareViewController.swift`
5. Add `ShareExtension/ShareViewController.swift` from this repo to the target

### 2. Configure URL scheme (deep link)

PivotStream target → **Info** tab → **URL Types → +**

| Field | Value |
|-------|-------|
| Identifier | `com.yourname.pivotstream` |
| URL Schemes | `pivotstream` |

This lets the extension open the app via `pivotstream://read?text=...`

### 3. Configure the extension Info.plist

Under `NSExtension → NSExtensionAttributes → NSExtensionActivationRule`:

```xml
<key>NSExtensionActivationSupportsText</key>
<true/>
<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
<integer>1</integer>
```

### 4. Add App Group (for data handoff)

In both the **PivotStream** and **ShareExtension** targets → **Signing & Capabilities → App Groups → +**

Add: `group.com.yourname.pivotstream`

---

## Web App Reference

Original web app (FastAPI + vanilla JS):

```
/Users/diegoandrade/Documents/GitHub/PivotStream
```

| Web | iOS |
|-----|-----|
| `/api/parse` | `TextParser.parse(_:)` |
| `_extract_epub_data()` | `EPUBParser.parse(url:)` |
| `_extract_pdf_data()` | `PDFParser.parse(url:)` |
| JS playback loop | `RSVPEngine.launchPlaybackTask()` |
| `showToken()` | `RSVPView` |
