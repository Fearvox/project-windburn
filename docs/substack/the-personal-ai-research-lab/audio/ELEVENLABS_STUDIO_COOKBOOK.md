# ElevenLabs Studio Podcast Cookbook

This is the Studio-facing recipe for Field Note 000.

## Current Finding

The voice is good. The content is not.

The current Studio draft reads like a webpage summary:

- third-person explanatory framing;
- "let's break it down" lecture cadence;
- too much definition, not enough authorial voice;
- polished summary without the field-note pulse.

Replace it with a spoken script: first-person, evidence-minded, compact, and written to be read aloud.

## Model Choice

Use `Eleven v3` when using audio tags such as `[thoughtful]`, `[short pause]`, or `[quietly amused]`.

Why:

- ElevenLabs documents square-bracket audio tags as an Eleven v3 feature.
- Eleven v3 is the expressive model for emotional delivery and dramatic performance.
- Eleven v3 does not support SSML `<break />` tags; use audio tags, punctuation, and text structure for pauses.

If staying on `Eleven Multilingual v2`, use the clean untagged script instead. It is more stable for long-form narration, but less responsive to audio tags.

## Recommended Studio Settings

- Voice: `Will - Relaxed Optimist`, if that is the voice currently sounding right.
- Model: `Eleven v3`.
- Stability: start at `Natural`; move toward `Creative` if tags feel too subtle, toward `Robust` if it drifts.
- Text: use `000-html-agents-elevenlabs-v3-studio-script.txt`.
- Regenerate in blocks if one paragraph goes weird. Keep the same voice/model.

## Tag Style

Use tags sparingly. The tags should guide the performance, not become a second script.

Good tags for this field note:

- `[thoughtful]`
- `[measured]`
- `[short pause]`
- `[quietly amused]`
- `[lower, precise]`
- `[firm]`
- `[gentle emphasis]`

Avoid:

- theatrical tags;
- too many tags per paragraph;
- tags that fight the voice, such as asking a calm voice to shout;
- summary phrases like "this workflow addresses" or "let's break it down."

## Source Text

Use the Studio script here:

- `docs/substack/the-personal-ai-research-lab/audio/000-html-agents-elevenlabs-v3-studio-script.txt`

The older MIMO script remains useful as source material, but this version is tuned for ElevenLabs Studio and v3 audio tags.
