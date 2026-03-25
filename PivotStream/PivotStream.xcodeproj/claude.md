# PivotStream - Project Documentation

## Overview

**PivotStream** is an iOS RSVP (Rapid Serial Visual Presentation) reader application that displays text one word at a time at a fixed focal point to increase reading speed. The app highlights the Optimal Recognition Point (ORP) of each word to help users read faster by eliminating saccadic eye movement.

**Created by:** Diego Andrade  
**Date:** March 20-22, 2026  
**Platform:** iOS  
**Language:** Swift  
**Framework:** SwiftUI with Observation  

## Core Concepts

### RSVP (Rapid Serial Visual Presentation)
Words are displayed sequentially at a single focal point on screen. Users keep their eyes fixed while text flows through the center, eliminating the time-consuming eye movements of traditional reading.

### ORP (Optimal Recognition Point)
The specific character in each word that the brain uses to instantly recognize the entire word. Displayed in red/accent color. Calculated based on word length:
- Words < 2 chars: index 0
- Words < 6 chars: index 1
- Words < 10 chars: index 2
- Words < 14 chars: index 3
- Words ≥ 14 chars: min(4, len - 1)

### Speed Ramping
Gradually increases reading speed (WPM) over time to help users naturally improve their reading pace. Can be toggled on/off.

### Pause Multiplier
Dynamic delay adjustment based on punctuation and word length:
- Period/exclamation/question: +2.0x
- Colon/semicolon: +1.8x
- Comma: +1.4x
- Long words (>8 chars): +0.1x per 4 chars

## Architecture

### Design Pattern
- **MVVM-inspired** architecture
- **SwiftUI** for all UI
- **Observation framework** (@Observable, @Bindable) for state management
- **Swift Concurrency** (async/await) for file parsing
- **No external dependencies** - all parsing is custom-built

### Key Components

#### 1. App Entry & Navigation
- **PivotStreamApp.swift**: @main entry point
- **ContentView.swift**: Main coordinator view with NavigationStack

#### 2. View Models
- **ReaderViewModel.swift**: Central state management
  - Manages playback state
  - Coordinates with RSVPEngine
  - Handles document loading (EPUB, PDF, text)
  - Tracks chapters and active position
  - Exposes UI state (metaMode, chapterMode, statusMessage)

#### 3. Playback Engine
- **RSVPEngine** (not in visible files): Core timing and token advancement
  - Timer-based playback (likely CADisplayLink or Timer)
  - WPM control with pause multiplier
  - Speed ramping logic
  - Token array management
  - Callbacks for UI updates

#### 4. UI Views
- **RSVPView.swift**: Word display with ORP highlighting
  - Monospaced font (44pt)
  - Fixed-width character slots for alignment
  - Red ORP guide line
  - Displays: prefix (gray) + left + **pivot (red)** + right + suffix (gray)

- **ControlsView.swift**: Playback controls
  - WPM slider (100-1600)
  - Play/Pause button (large circular)
  - Jump ±10 words buttons with custom vertical stack icons (chevron + number)
  - Restart, Ramp toggle, Meta display buttons
  - Custom button styles (PrimaryButtonStyle, ControlButtonStyle, SecondaryButtonStyle)

- **InputPanelView.swift**: Text input and file import
  - TextEditor for direct text input
  - EPUB file picker
  - PDF file picker
  - Sample text loader
  - Loading state with status messages

- **ChaptersView.swift**: Chapter navigation
  - Hierarchical chapter list with indentation
  - Shows word position for each chapter
  - Highlights active chapter
  - Different titles for EPUB ("Chapters") vs PDF ("Sections")

#### 5. Models
- **Token.swift**: Word token model
  - Properties: core, prefix, suffix, orpIndex, pauseMult
  - Computed: left, pivot, right (for display)

- **Chapter.swift**: Chapter/section model
  - Properties: id, title, startIndex, level

#### 6. Parsers

##### EPUBParser.swift
Complete EPUB 2 & 3 parser:
1. Uses ZipReader to extract archive
2. Reads META-INF/container.xml to find OPF path
3. Parses OPF file for manifest + spine
4. Extracts TOC from EPUB3 nav or EPUB2 NCX
5. Reads HTML files in spine order
6. Converts HTML to plain text
7. Tracks chapter positions
8. Returns EPUBResult with text and chapters

**Key methods:**
- `parse(url:)` → EPUBResult
- `parseContainerXML(_:)` → OPF path
- `parseOPF(_:baseDir:)` → OPFData
- `parseEPUB3Nav(_:)` → [TOCItem]
- `parseNCX(_:)` → [TOCItem]
- `htmlToText(_:)` → String
- `unescapeHTML(_:)` → String (handles &amp;, &#160;, &#x00A0;, etc.)

Uses SimpleXMLParser (SAX-style) for XML parsing.

##### PDFParser.swift
PDF text extraction with section detection:
1. Opens PDF with PDFKit
2. Extracts text from all pages
3. Detects sections using regex patterns:
   - Numeric: "1." "1.2." "1.2.3."
   - Roman: "I." "II." "III." etc.
   - Alphabetic: "A." "B." etc.
4. Returns PDFResult with text, page count, and chapters

##### TextParser.swift
Tokenization and normalization:
- `parse(_:)` → [Token]: Main entry point
- `normalize(_:)`: Whitespace and newline cleanup
- `splitToken(_:)` → Token?: Splits word into prefix/core/suffix
- `computeORP(_:)`: Calculates ORP index
- `computePauseMult(suffix:coreLength:)`: Calculates pause multiplier

##### ZipReader.swift
Custom ZIP archive reader (no dependencies):
- Supports stored (method 0) and deflate (method 8) compression
- Uses zlib for decompression
- Parses ZIP structures: EOCD, central directory, local headers
- **Key methods:**
  - `readAll()` → [String: Data]
  - `readFile(_:)` → Data
  - `fileNames()` → [String]

#### 7. Share Extension
- **ShareViewController.swift**: iOS Share Extension
  - Accepts plain text and URLs
  - Uses App Group: `group.com.yourname.pivotstream`
  - URL scheme: `pivotstream://read?text=`
  - Falls back to UserDefaults for handoff

#### 8. Theme
- **Theme.swift**: Color definitions and utilities
  - `Color.orpAccent`: Red accent (maps to AccentColor asset)
  - `Color.rsvpRed`: Apple System Red (#FF3B30) for light mode
  - `Color.rsvpRedDark`: Brighter red (#FF453A) for dark mode
  - `Color.readerBackground`: Slightly tinted adaptive background
  - `init(hex:)`: Helper extension for creating colors from hex strings

- **Assets.xcassets**: Asset catalog
  - AccentColor: Red color asset (recommended #FF3B30)
  - AppIcon: App icon set (1024x1024 + device-specific sizes)
- **Theme.swift**: Color definitions
  - `Color.orpAccent`: Red accent (maps to AccentColor asset)
  - `Color.readerBackground`: Slightly tinted background

## File Structure

```
PivotStream/
├── PivotStreamApp.swift          # App entry
├── ContentView.swift              # Main coordinator
├── ReaderViewModel.swift          # State management
├── Views/
│   ├── RSVPView.swift            # Word display
│   ├── ControlsView.swift        # Playback controls
│   ├── InputPanelView.swift      # Text input
│   └── ChaptersView.swift        # Chapter list
├── Models/
│   ├── Token.swift               # Word token
│   └── Chapter.swift             # Chapter model
├── Parsers/
│   ├── EPUBParser.swift          # EPUB reader
│   ├── PDFParser.swift           # PDF reader
│   ├── TextParser.swift          # Tokenizer
│   └── ZipReader.swift           # ZIP extractor
├── Theme.swift                   # Colors
└── ShareExtension/
    └── ShareViewController.swift # Share extension
```

## Data Flow

```
User Input (EPUB/PDF/Text)
    ↓
ReaderViewModel.loadEPUB/loadPDF/loadText
    ↓
EPUBParser/PDFParser extracts text + chapters
    ↓
TextParser.parse() → [Token]
    ↓
RSVPEngine.load(tokens)
    ↓
User taps Play
    ↓
RSVPEngine.start() → Timer begins
    ↓
On each tick:
  - Calculate delay (60000 / wpm * pauseMult)
  - Advance currentIndex
  - Call onAdvance callback
    ↓
ReaderViewModel.updateActiveChapter()
    ↓
RSVPView updates with new token
```

## Key Algorithms

### ORP Calculation
```swift
switch wordLength {
case ..<2: return 0
case ..<6: return 1
case ..<10: return 2
case ..<14: return 3
default: return min(4, wordLength - 1)
}
```

### Token Display Alignment
Uses monospaced font with fixed character slots:
- 4 slots for left side (prefix + left)
- 1 slot for pivot (ORP)
- 14 slots for right side (right + suffix)
- Guide line at pivot position

### Chapter Tracking
When token index advances:
1. Find the last chapter with startIndex ≤ currentIndex
2. Update activeChapterIndex
3. UI highlights active chapter in list

### EPUB TOC Parsing
1. Try EPUB3 nav first (HTML with `<a href>` links)
2. Fall back to EPUB2 NCX (XML with `<navPoint>` elements)
3. Extract title + href for each entry
4. Match href to spine items to determine token positions

### PDF Section Detection
Uses regex patterns to identify headers:
- Numeric: `^(\d+\.)+\s+[A-Z][^\n]{2,60}$`
- Roman: `^(I{1,3}|IV|V|VI{0,3}|IX|X{1,3}|...)\.?\s+[A-Z][^\n]{2,60}$`
- Alphabetic: `^[A-Z]\.\s+[A-Z][^\n]{2,60}$`

Filters out noise (units like MB, GB, KB, etc.)

## Testing Notes

### Sample Text
Hardcoded sample explains RSVP, ORP, and basic controls. Useful for first launch and demos.

### EPUB Support
- Handles both EPUB2 and EPUB3
- Supports nested chapters (levels)
- Handles HTML entities and various encodings
- Strips script/style blocks

### PDF Support
- Extracts plain text only (no images)
- Section detection is heuristic-based
- Works best with well-structured documents

## Future Considerations

### Missing Files
- **RSVPEngine.swift**: Playback engine implementation not visible
  - Likely uses Timer or CADisplayLink
  - Manages token array and currentIndex
  - Implements ramp logic
  - Calculates per-token delays

### Potential Improvements
- Persistence (save reading position)
- Bookmarks
- Reading statistics
- More granular speed control
- Custom ORP algorithms
- Dark mode enhancements
- Accessibility support (VoiceOver hints)
- URL scheme handling in app
- Share extension improvements (direct EPUB/PDF sharing)

## API Surface

### ReaderViewModel Public API
```swift
// Playback
func play()
func pause()
func resume()
func restart()
func toggleRamp()
func jumpWords(_ delta: Int)
func jumpToChapter(_ index: Int)

// Input
func loadText(_ text: String)
func loadSample()
func loadEPUB(url: URL) async
func loadPDF(url: URL) async

// State
var tokens: [Token] { get }
var currentIndex: Int { get }
var isPlaying: Bool { get }
var wpm: Double { get set }
var rampEnabled: Bool { get }
var chapters: [Chapter]
var activeChapterIndex: Int?
var metaMode: MetaMode { get set }
var chapterMode: ChapterMode
```

### TextParser Public API
```swift
static func parse(_ text: String) -> [Token]
static func normalize(_ text: String) -> String
static func splitToken(_ word: String) -> Token?
static func computeORP(_ len: Int) -> Int
static func computePauseMult(suffix: String, coreLength: Int) -> Double
```

### EPUBParser Public API
```swift
static func parse(url: URL) throws -> EPUBResult
static func htmlToText(_ html: String) -> String
```

### PDFParser Public API
```swift
static func parse(url: URL) throws -> PDFResult
```

### ZipReader Public API
```swift
init(url: URL) throws
func readAll() throws -> [String: Data]
func readFile(_ name: String) throws -> Data
func fileNames() throws -> [String]
```

## Dependencies

### System Frameworks
- SwiftUI
- Foundation
- PDFKit (for PDF parsing)
- zlib (for ZIP decompression)
- UniformTypeIdentifiers (for file pickers)

### No Third-Party Dependencies
All parsing and processing is implemented from scratch.

## Build Configuration

- **App Group:** `group.com.yourname.pivotstream`
- **URL Scheme:** `pivotstream://`
- **Share Extension Target:** ShareExtension
- **Minimum iOS Version:** Likely iOS 17+ (uses Observation framework)

## Design Philosophy

1. **Zero Dependencies**: All parsing is custom-built for learning and control
2. **Modern Swift**: Uses latest Swift features (Observation, async/await)
3. **Clean Architecture**: Clear separation between UI, state, and parsing
4. **Performance**: Efficient tokenization and parsing for large documents
5. **User Experience**: Smooth playback with intelligent pausing

## Notes for AI Assistants

- The project uses **@Observable** macro, not ObservableObject
- Use **@Bindable** for two-way bindings in views
- All parsers are **nonisolated** for safe concurrent access
- The RSVPEngine file is not visible but is referenced throughout
- Color theme uses **Color.orpAccent** (red) and **Color.readerBackground**
- Token display uses **monospaced font** for precise ORP alignment
- EPUB parsing is comprehensive and handles edge cases well
- PDF section detection is heuristic and may need tuning for specific documents

## Common Tasks

### Adding New Document Format
1. Create new parser in Parsers/ folder
2. Follow pattern: static parse(url:) throws -> Result
3. Return text + chapters array
4. Add UI button in InputPanelView
5. Add handler in ReaderViewModel
6. Update ChapterMode enum if needed

### Modifying ORP Algorithm
Edit `TextParser.computeORP(_ len: Int)` function.

### Adjusting Pause Timing
Edit `TextParser.computePauseMult(suffix:coreLength:)` function.

### Changing Display Layout
Modify RSVPView slot counts (leftSlots, rightSlots) and fontSize.

### Adding New Button Style
Create new ButtonStyle conformance in ControlsView.swift.
