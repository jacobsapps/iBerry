# iBerry

A tiny iOS keyboard extension: one heavy impact on touch-down, another on touch-up.
Five production Swift files, no packages, networking, analytics, or saved keystrokes.

## Read it in this order

1. **Keyboard/Haptics.swift** — owns a reusable heavy impact generator.
2. **Keyboard/KeyButton.swift** — maps UIKit touch events to feedback and an action.
3. **Keyboard/Spellcheck.swift** — asks UIKit for spelling candidates; defines a conservative correction policy.
4. **Keyboard/KeyboardViewController.swift** — builds keys and suggestions; edits through the document proxy.
5. **App/App.swift** — setup instructions and a text editor.

The controller owns one haptic service and passes it to every key. A key knows
how a press feels, not what it means. UIKit owns tracking; there is no custom
press state machine, protocol layer, shared app state, or keyboard framework.

### The whole interaction

- Touch down: request one heavy impact.
- Release inside: request one heavy impact, then perform the key's action.
- Release outside: request one heavy impact, but do not type.
- System cancellation: do not request an up impact or type.
- Dragging out and back in: no extra impacts.
- Accessibility activation: the same pair of requests, then the action.

## Run

Open `iBerry.xcodeproj`, select **iBerry**, and run.
For an iPhone, select your development team for the app and extension targets.
The app explains how to add the keyboard in Settings and enable Full Access.
Use the system globe to select it. The extension's own globe, when required,
cycles to the next keyboard.

The project is included; XcodeGen is only needed after changing `project.yml`.
Use `xcodegen generate` to regenerate it. Run unit tests with Command-U.

## Verification and limits

Thirty-one tests cover event ordering, outside release, drag, cancellation,
accessibility, generator preparation, layout, suggestion styling, token boundaries,
spelling candidates, confidence rules, punctuation correction, undo, and host opt-out. They test the
software requests, not physical vibration. Simulator interaction also verified
real extension typing, deletion, shift, symbols, spaces, return, and insertion
on release rather than down.

A real iPhone is still required to feel both impacts. iOS, hardware support,
access permissions and timing govern actual delivery; two API calls do not
guarantee two distinguishable sensations on very fast taps.

This is deliberately not a full replacement for Apple's keyboard: no contextual
next-word predictions, swipe typing, long-press alternates, delete repeat,
caps lock or localisation. Secure fields and some apps use the system keyboard.

Architecture diagram: `docs/architecture.html`.
Local build/test evidence and native screenshots: `artifacts/` (gitignored).

## Native visual refinement

The keyboard uses 42 pt caps, 12 pt row gutters, consistent letter widths,
SF Symbols, optical text alignment, and light/dark colors measured against
the iOS 18 keyboard on the same simulator. Three visual passes were inspected.
Local before/reference/after review: artifacts/visual-refinement/comparison.html.
This is not a claim of pixel-identical rendering on every iOS release.

## Spelling: a native service, not another dependency

`Spellcheck.swift` wraps Apple's on-device `UITextChecker` with English (`en_US`).
No downloaded dictionary, package, server, or saved typing history.

- The three-slot bar shows the original word and up to two real spelling/completion candidates.
- Tap a candidate to replace the current word and insert a space.
- Tap the quoted original to keep exactly what you typed.
- Space, return, and `. , ! ? ; :` accept only confident corrections of misspelled lowercase words.
- **Unique adjacent swap:** at least three letters; the top spelling guess must be
  the only adjacent-swap candidate (`teh → the`, `recieve → receive`).
- **Other one-edit typos:** at least five letters; the top guess must be the only
  one-edit candidate across the entire spelling-guess list—not just the visible two.
- Ambiguous/short words stay suggestions only. Completions never drive autocorrect.
- Immediate backspace removes the correction and its boundary, restoring the
  original word. Retyping a boundary keeps the restored spelling.
- Selections, mid-word cursors, address/number fields, URLs, mixed-number tokens,
  and identifiers are excluded. Host autocorrection-off is respected.

This is word-level spelling, not Apple's contextual QuickType engine. Candidate
order depends on the OS dictionary. Confidence is a conservative heuristic, not
a probability; uncommon lowercase names can still be corrected.
No available English dictionary means no suggestions or automatic replacements.

Live installed-extension checks: `teh → the → teh` (space, then undo), preserving
that undo on the next space, tapping `recieve → receive`, and keeping the quoted original.
Current autocorrect review: `artifacts/autocorrect/review.html`.
Test results: `artifacts/autocorrect/iBerryVerified.xcresult`.
Earlier spelling review: `artifacts/spellcheck/review.html`.
Previous visual passes: `artifacts/passes-4-5/comparison.html`.
