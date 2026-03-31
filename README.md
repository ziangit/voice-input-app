# VoiceInput

A lightweight macOS menu bar app that lets you dictate text into any input field using the **Fn / Globe key** as a push-to-talk trigger. Transcription runs on-device via Apple's Speech framework, with an optional LLM post-processing step to fix recognition errors.

## Features

- **Push-to-talk** — hold Fn (Globe) to record, release to transcribe and inject text
- **On-device transcription** — uses Apple's built-in Speech Recognition, no cloud required
- **Multi-language** — supports English, Simplified Chinese, Traditional Chinese, Japanese, and Korean
- **LLM refinement** — optionally sends transcribed text to any OpenAI-compatible API to fix homophones and technical term errors
- **Floating HUD** — shows live partial transcription and audio waveform while recording
- **Menu bar only** — no Dock icon, stays out of your way

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Microphone and Speech Recognition permissions

## Build & Run

```bash
# Build and launch directly
make run

# Or install to /Applications
make install
```

On first launch, macOS will prompt for **Microphone** and **Speech Recognition** access — both are required.

If macOS blocks the app from opening, remove the quarantine flag:

```bash
xattr -cr /Applications/VoiceInput.app
```

## Usage

1. Focus any text field (browser, editor, chat app, etc.)
2. Hold **Fn (Globe)** to start recording — a floating HUD appears
3. Speak your text
4. Release **Fn (Globe)** — the transcription is typed into the focused field

## LLM Refinement (Optional)

LLM refinement corrects common speech recognition mistakes such as Chinese homophones and technical terms being transcribed phonetically (e.g. "配森" → "Python", "阿皮" → "API").

To enable it:

1. Click the menu bar mic icon → **LLM Refinement** → **Settings…**
2. Enter your API base URL (any OpenAI-compatible endpoint), API key, and model name
3. Enable **LLM Refinement** from the menu

## Permissions

| Permission | Why |
|---|---|
| Microphone | Capture audio for transcription |
| Speech Recognition | On-device transcription via Apple's Speech framework |
| Accessibility | Inject transcribed text into the focused input field |

## Inspiration

Inspired by [yetone/voice-input-src](https://github.com/yetone/voice-input-src), a voice input app whose entire source code is a prompt — a fun exploration of AI-assisted development.

## License

MIT
