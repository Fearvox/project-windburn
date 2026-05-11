#!/usr/bin/env node
import { mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, extname } from "node:path";
import { spawnSync } from "node:child_process";

const DEFAULT_BASE_URL = "https://api.xiaomimimo.com/v1";

function usage(exitCode = 0) {
  const stream = exitCode === 0 ? process.stdout : process.stderr;
  stream.write(`Usage:
  node scripts/mimo-podcast-tts.mjs --input script.md --out audio.wav [options]

Options:
  --input <path>       Markdown/text file to synthesize.
  --out <path>         Output audio path.
  --model <id>         Default: mimo-v2.5-tts
  --voice <id>         Default: Chloe
  --format <fmt>       Default: wav
  --style <text>       Voice direction prompt for the user message.
  --style-file <path>  Read voice direction prompt from a file.
  --chunk-chars <n>    Split long scripts into chunks and concatenate output.
  --keep-parts         Keep chunk part files after concatenation.
  --base-url <url>     Default: MIMO_BASE_URL or ${DEFAULT_BASE_URL}
  --dry-run            Print a redacted payload summary without sending.
  --help               Show this help.
`);
  process.exit(exitCode);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") usage(0);
    if (arg === "--dry-run") {
      args.dryRun = true;
      continue;
    }
    if (!arg.startsWith("--")) {
      throw new Error(`Unexpected positional argument: ${arg}`);
    }
    const key = arg.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    const value = argv[i + 1];
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for ${arg}`);
    }
    args[key] = value;
    i += 1;
  }
  return args;
}

function requireArg(args, name) {
  if (!args[name]) {
    throw new Error(`Missing required --${name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`);
  }
  return args[name];
}

function stripMarkdownForSpeech(source) {
  return source
    .replace(/^# .*\n+/, "")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function splitIntoChunks(text, maxChars) {
  if (!maxChars || text.length <= maxChars) {
    return [text];
  }

  const paragraphs = text.split(/\n{2,}/).map((p) => p.trim()).filter(Boolean);
  const chunks = [];
  let current = "";

  for (const paragraph of paragraphs) {
    if (paragraph.length > maxChars) {
      if (current) {
        chunks.push(current.trim());
        current = "";
      }
      const sentences = paragraph.match(/[^.!?]+[.!?]+|[^.!?]+$/g) || [paragraph];
      for (const sentence of sentences.map((s) => s.trim()).filter(Boolean)) {
        if ((current + "\n\n" + sentence).trim().length > maxChars && current) {
          chunks.push(current.trim());
          current = "";
        }
        current = (current ? `${current}\n\n${sentence}` : sentence).trim();
      }
      continue;
    }

    const candidate = (current ? `${current}\n\n${paragraph}` : paragraph).trim();
    if (candidate.length > maxChars && current) {
      chunks.push(current.trim());
      current = paragraph;
    } else {
      current = candidate;
    }
  }

  if (current) {
    chunks.push(current.trim());
  }

  return chunks;
}

function tokenPlanLooksLikely(apiKey) {
  return apiKey.trim().startsWith("tp-");
}

async function synthesize(payload, baseUrl, apiKey) {
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": apiKey,
    },
    body: JSON.stringify(payload),
  });

  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`MiMo returned non-JSON response (${response.status}): ${text.slice(0, 500)}`);
  }

  if (!response.ok) {
    const message = json?.error?.message || json?.message || text.slice(0, 500);
    throw new Error(`MiMo request failed (${response.status}): ${message}`);
  }

  const audioData = json?.choices?.[0]?.message?.audio?.data;
  if (!audioData) {
    throw new Error(`MiMo response did not include choices[0].message.audio.data. Keys: ${Object.keys(json).join(", ")}`);
  }

  return Buffer.from(audioData, "base64");
}

function concatWithFfmpeg(partPaths, outPath) {
  const ffmpeg = spawnSync("ffmpeg", ["-version"], { encoding: "utf8" });
  if (ffmpeg.status !== 0) {
    throw new Error("Chunked output requires ffmpeg for concatenation.");
  }

  const args = [
    "-y",
    "-hide_banner",
    "-loglevel",
    "error",
    ...partPaths.flatMap((path) => ["-i", path]),
    "-filter_complex",
    `concat=n=${partPaths.length}:v=0:a=1[a]`,
    "-map",
    "[a]",
    outPath,
  ];
  const result = spawnSync("ffmpeg", args, { encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`ffmpeg concat failed: ${result.stderr || result.stdout}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = requireArg(args, "input");
  const outPath = requireArg(args, "out");

  const model = args.model || "mimo-v2.5-tts";
  const usesVoiceDesign = model.includes("voicedesign");
  const voice = args.voice || (usesVoiceDesign ? "" : "Chloe");
  const format = args.format || extname(outPath).replace(".", "") || "wav";
  const chunkChars = args.chunkChars ? Number.parseInt(args.chunkChars, 10) : 0;
  const baseUrl = (args.baseUrl || process.env.MIMO_BASE_URL || DEFAULT_BASE_URL).replace(/\/+$/, "");
  const apiKey = process.env.MIMO_API_KEY || process.env.XIAOMI_API_KEY || "";
  const styleFromFile = args.styleFile ? readFileSync(args.styleFile, "utf8").trim() : "";
  const style =
    styleFromFile ||
    args.style ||
    "Warm, crisp English podcast narrator. Measured pace, calm confidence, intelligent but not stiff. Preserve short pauses between sections. Slightly intimate field-note energy.";

  const source = readFileSync(inputPath, "utf8");
  const speechText = stripMarkdownForSpeech(source);

  if (!speechText) {
    throw new Error(`No speech text found in ${inputPath}`);
  }

  const payload = {
    model,
    messages: [
      { role: "user", content: style },
      { role: "assistant", content: speechText },
    ],
    audio: {
      format,
    },
  };

  if (voice) {
    payload.audio.voice = voice;
  }

  const summary = {
    endpoint: `${baseUrl}/chat/completions`,
    model,
    voice,
    format,
    inputPath,
    outPath,
    styleFile: args.styleFile || null,
    styleChars: style.length,
    speechChars: speechText.length,
    chunks: splitIntoChunks(speechText, chunkChars).map((chunk) => chunk.length),
    hasMimoApiKey: Boolean(process.env.MIMO_API_KEY),
    hasXiaomiApiKeyFallback: !process.env.MIMO_API_KEY && Boolean(process.env.XIAOMI_API_KEY),
    tokenPlanKeyLikely: Boolean(apiKey && tokenPlanLooksLikely(apiKey)),
    payloadShape: {
      messages: ["user style prompt", "assistant spoken text"],
      audio: payload.audio,
    },
  };

  if (args.dryRun) {
    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
    return;
  }

  if (!apiKey) {
    throw new Error("Set MIMO_API_KEY before generating audio. XIAOMI_API_KEY is accepted only as a fallback.");
  }

  if (tokenPlanLooksLikely(apiKey) && !args.baseUrl && !process.env.MIMO_BASE_URL) {
    throw new Error(
      "Token Plan key detected. Set MIMO_BASE_URL to the OpenAI-compatible Token Plan base URL from the MiMo Subscription console."
    );
  }

  mkdirSync(dirname(outPath), { recursive: true });
  const chunks = splitIntoChunks(speechText, chunkChars);
  const partPaths = [];

  if (chunks.length === 1) {
    writeFileSync(outPath, await synthesize(payload, baseUrl, apiKey));
  } else {
    for (let i = 0; i < chunks.length; i += 1) {
      const partPayload = {
        ...payload,
        messages: [
          payload.messages[0],
          { role: "assistant", content: chunks[i] },
        ],
      };
      const partPath = `${outPath}.part-${String(i + 1).padStart(2, "0")}.${format}`;
      writeFileSync(partPath, await synthesize(partPayload, baseUrl, apiKey));
      partPaths.push(partPath);
      process.stderr.write(`generated chunk ${i + 1}/${chunks.length}: ${partPath}\n`);
    }
    concatWithFfmpeg(partPaths, outPath);
    if (!args.keepParts) {
      for (const partPath of partPaths) {
        unlinkSync(partPath);
      }
    }
  }

  process.stdout.write(
    `${JSON.stringify(
      {
        ok: true,
        outPath,
        chunks: chunks.length,
        model,
        voice,
        format,
      },
      null,
      2
    )}\n`
  );
}

main().catch((error) => {
  process.stderr.write(`mimo-podcast-tts: ${error.message}\n`);
  process.exit(1);
});
