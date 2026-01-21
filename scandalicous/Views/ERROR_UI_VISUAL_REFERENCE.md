# Receipt Error UI Visual Reference

## Component Structure

```
┌─────────────────────────────────────┐
│                                     │
│         ╔═══════════╗               │
│         ║           ║               │
│         ║     ✕     ║  ← Red Circle │
│         ║           ║     80x80pt   │
│         ╚═══════════╝               │
│                                     │
│     Processing Failed!              │ ← Title (24pt bold)
│                                     │
│   Error message displayed here      │ ← Message (16pt)
│   with details about what went      │
│   wrong and how to fix it           │
│                                     │
│   ┌─────────────────────────────┐   │
│   │   🔄  Try Again             │   │ ← Retry (optional)
│   └─────────────────────────────┘   │
│                                     │
│   ┌─────────────────────────────┐   │
│   │        Dismiss              │   │ ← Dismiss
│   └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

## Color Palette

### Red Circle (Gradient)
- **Top Left**: `rgb(255, 77, 77)` / `#FF4D4D`
- **Bottom Right**: `rgb(230, 51, 51)` / `#E63333`
- **Shadow**: Red with 50% opacity, 20pt blur

### X Icon
- **Color**: White `#FFFFFF`
- **Size**: 40pt
- **Weight**: Bold

### Background
- **Material**: `.ultraThinMaterial`
- **Corner Radius**: 24pt
- **Shadow**: Black 30% opacity, 20pt blur, 10pt offset

### Text
- **Title**: Primary color (white in dark mode)
- **Message**: Secondary color (gray)
- **Button Text**: White on blue/gray background

## States

### 1. Quality Error (with retry)
```
Title: "Quality Check Failed"
Message: "Receipt quality too low for accurate processing.

Issues detected:
• Image is too blurry
• Poor lighting conditions

Quality Score: 45%
Minimum Required: 60%

Tips:
• Ensure good lighting
• Hold device steady
• Capture entire receipt"

Buttons: [Try Again] [Cancel]
```

### 2. Upload Error (with retry)
```
Title: "Processing Failed!"
Message: "Failed to upload receipt to server. Please check your 
internet connection and try again."

Buttons: [Try Again] [Cancel]
```

### 3. Generic Error (no retry)
```
Title: "Processing Failed!"
Message: "The receipt could not be processed by the server."

Buttons: [Dismiss]
```

### 4. Share Extension Error (no retry)
```
Title: "Processing Failed!"
Message: "Unsupported file type: .heic"

Buttons: [Dismiss]
```

## Animations

### Entry Animation
- **Type**: Spring + Scale + Opacity
- **Duration**: 0.3 seconds
- **Damping**: 0.7
- **Transform**: Scale from 0.9 to 1.0
- **Opacity**: From 0.0 to 1.0

### Button Press
- **Type**: Spring
- **Duration**: 0.3 seconds
- **Damping**: 0.6
- **Transform**: Scale to 0.95
- **Opacity**: To 0.8

### Exit Animation
- **Type**: Spring + Scale + Opacity
- **Duration**: 0.3 seconds
- **Damping**: 0.7
- **Transform**: Scale from 1.0 to 0.9
- **Opacity**: From 1.0 to 0.0

## Responsive Design

### iPhone (Portrait)
- **Width**: Max 400pt, min 32pt margins
- **Height**: Auto-sizing based on content
- **Position**: Centered vertically and horizontally

### iPhone (Landscape)
- **Same as portrait** - consistent experience

### iPad
- **Width**: Max 400pt (doesn't expand to full width)
- **Position**: Centered
- **Same design** - maintains consistency

## Haptic Feedback

### On Error Shown
- **Type**: `.notificationOccurred(.error)`
- **Pattern**: Error pattern (3 sharp taps)

### On Retry Tapped
- **Type**: `.impactOccurred(.light)`
- **Pattern**: Single light tap

### On Dismiss Tapped
- **Type**: `.impactOccurred(.light)`
- **Pattern**: Single light tap

## Accessibility

### VoiceOver
- **Red Circle**: "Error icon"
- **Title**: Read as heading
- **Message**: Read as normal text
- **Retry Button**: "Try Again button. Double tap to retry upload."
- **Dismiss Button**: "Dismiss button. Double tap to dismiss."

### Dynamic Type
- All text scales with system font size
- Maintains minimum touch targets (44x44pt)

### Reduced Motion
- When enabled, uses fade instead of scale
- Simplified transitions
- No spring physics

### Color Contrast
- All text meets WCAG AA standards
- Red circle has sufficient contrast with X
- Buttons have clear visual distinction

## Platform Differences

### iOS/iPadOS (SwiftUI)
- Uses `ReceiptErrorView`
- Applied via `.receiptErrorOverlay()` modifier
- Full sheet presentation over content

### Share Extension (UIKit)
- Uses `ReceiptErrorViewController`
- Presented modally with `.overFullScreen`
- Same visual design, different implementation

## Implementation Details

### Background Overlay
- **Color**: Black with 50% opacity
- **Behavior**: Tappable (dismisses on tap outside)
- **Transition**: Fade in/out

### Content Card
- **Padding**: 32pt all around
- **Spacing**: 24pt between major elements
- **Button Spacing**: 12pt between buttons
- **Max Width**: 400pt

### Button Styling
- **Retry Button**:
  - Background: Blue `systemBlue`
  - Height: 50pt
  - Corner Radius: 12pt
  
- **Dismiss Button**:
  - Background: White 10% opacity
  - Height: 50pt
  - Corner Radius: 12pt

## Usage Context

### Main App Errors
✅ Shows with retry button
✅ User can retry upload
✅ Clear actionable feedback

### Share Extension Errors  
✅ Shows without retry
✅ User must dismiss
✅ Extension closes cleanly

### Quality Check Errors
✅ Shows detailed feedback
✅ Includes tips for improvement
✅ Retry button available

---

This consistent design ensures users always know when something went wrong and what they can do about it! 🎯
