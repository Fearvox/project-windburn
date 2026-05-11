# MIMO Podcast Audio Cookbook

This is the local recipe for turning a Substack field note into podcast audio with Xiaomi MiMo TTS.

## Source Of Truth

- TTS endpoint shape: `POST {base_url}/chat/completions`
- Pay-as-you-go OpenAI-compatible base URL: `https://api.xiaomimimo.com/v1`
- Token Plan base URL: use the exact OpenAI-compatible base URL shown in the MiMo Subscription console. Examples in the docs include regional URLs such as `https://token-plan-sgp.xiaomimimo.com/v1`.
- API key env: `MIMO_API_KEY`
- OpenClaw also recognizes `XIAOMI_API_KEY`; the local helper accepts it as a fallback, but `MIMO_API_KEY` is the preferred env name for this recipe.

## TTS Request Shape

MiMo TTS is Chat Completions-shaped, but the spoken target text must be in an `assistant` message.

```json
{
  "model": "mimo-v2.5-tts",
  "messages": [
    {
      "role": "user",
      "content": "Warm, crisp podcast narrator. Measured pace, intelligent but not stiff."
    },
    {
      "role": "assistant",
      "content": "This text is what will be spoken."
    }
  ],
  "audio": {
    "format": "wav",
    "voice": "Chloe"
  }
}
```

The response audio is base64 at `choices[0].message.audio.data`; decode it and write the bytes to the output file.

## Voices

Good first-pass voices for an English technical field note:

- `Chloe`: clear English female voice, good for warm narration.
- `Mia`: default-ish English female voice, useful for neutral readouts.
- `Dean`: English male voice, good for deeper documentary reads.
- `Milo`: English male voice, a little lighter.

Chinese built-ins include `冰糖`, `茉莉`, `苏打`, and `白桦`. `mimo_default` selects the platform default for the deployed cluster.

## Local Commands

Dry-run the payload shape without sending text:

```bash
node scripts/mimo-podcast-tts.mjs \
  --input docs/substack/the-personal-ai-research-lab/audio/000-html-agents-podcast-script.md \
  --out docs/substack/the-personal-ai-research-lab/audio/out/000-html-agents-can-remember.wav \
  --dry-run
```

Generate audio with pay-as-you-go credentials:

```bash
source ~/.zshrc
node scripts/mimo-podcast-tts.mjs \
  --input docs/substack/the-personal-ai-research-lab/audio/000-html-agents-podcast-script.md \
  --out docs/substack/the-personal-ai-research-lab/audio/out/000-html-agents-can-remember.wav \
  --voice Chloe
```

Generate audio with Token Plan credentials:

```bash
source ~/.zshrc
MIMO_BASE_URL="https://token-plan-sgp.xiaomimimo.com/v1" \
node scripts/mimo-podcast-tts.mjs \
  --input docs/substack/the-personal-ai-research-lab/audio/000-html-agents-podcast-script.md \
  --out docs/substack/the-personal-ai-research-lab/audio/out/000-html-agents-can-remember.wav \
  --voice Chloe
```

Use the Token Plan base URL from the MiMo console, not the example blindly.

Generate a prompted voice with MiMo voice design:

```bash
source ~/.zshrc
node scripts/mimo-podcast-tts.mjs \
  --model mimo-v2.5-tts-voicedesign \
  --style-file docs/substack/the-personal-ai-research-lab/audio/voice-prompts/codex-london-male.md \
  --input docs/substack/the-personal-ai-research-lab/audio/000-html-agents-podcast-script.md \
  --out docs/substack/the-personal-ai-research-lab/audio/out/000-html-agents-can-remember-london-male-full.wav \
  --chunk-chars 850
```

For `mimo-v2.5-tts-voicedesign`, the helper omits `audio.voice`; the voice prompt goes in the `user` message and the spoken script goes in the `assistant` message.
Voice-design calls can silently cap a long single request around one minute, so use `--chunk-chars` for full episodes.

## Guardrails

- Do not commit keys or console screenshots containing keys.
- Do not paste private transcripts into a public audio script unless they are intentionally publishable.
- Keep the source script in markdown and the generated audio under `audio/out/`.
- For long episodes, split into segments and stitch later. The TTS API is single-speaker per call; make two calls if we want host/interviewer voices.
- For streaming, MiMo says `pcm16` is the right audio format, but V2.5 streaming is currently compatibility-mode and returns once after inference completes. Non-streaming `wav` is the simplest path for Substack.
