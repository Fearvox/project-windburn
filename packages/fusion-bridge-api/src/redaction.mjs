export const sensitivePatterns = [
  { name: "raw IPv4 address", pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g },
  { name: "raw IPv6 address", pattern: /\b(?:[A-Fa-f0-9]{1,4}:){2,}[A-Fa-f0-9:]{1,}\b/g },
  { name: "macOS local path", pattern: /\/Users\/[^\s"'`),]+/g },
  { name: "remote server path", pattern: /\/srv\/[^\s"'`),]+/g },
  { name: "ssh target", pattern: /\bssh\s+[^\n]+/gi },
  { name: "email", pattern: /([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g },
  { name: "bearer token", pattern: /Bearer\s+[A-Za-z0-9._-]+/g },
  { name: "query secret", pattern: /(?<=[?&](?:token|key|secret|password)=)[^&\s]+/gi },
  { name: "xAI key", pattern: /(xai-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]{32,}/g },
  { name: "OpenAI-style key", pattern: /(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]{32,}/g },
  { name: "GitHub token", pattern: /\b(?:gho|ghp|github_pat)_[A-Za-z0-9_]{16,}\b/g },
];

export function redact(value) {
  return String(value)
    .replace(sensitivePatterns[0].pattern, "[redacted:host]")
    .replace(sensitivePatterns[1].pattern, "[redacted:host]")
    .replace(sensitivePatterns[2].pattern, "[redacted:local-path]")
    .replace(sensitivePatterns[3].pattern, "[redacted:remote-path]")
    .replace(sensitivePatterns[4].pattern, "ssh [redacted:target]")
    .replace(sensitivePatterns[5].pattern, "[redacted:email]")
    .replace(sensitivePatterns[6].pattern, "Bearer [redacted]")
    .replace(sensitivePatterns[7].pattern, "[redacted]")
    .replace(sensitivePatterns[8].pattern, "$1[redacted]")
    .replace(sensitivePatterns[9].pattern, "$1[redacted]")
    .replace(sensitivePatterns[10].pattern, "[redacted:token]");
}

export function assertStreamSafe(payload) {
  const text = typeof payload === "string" ? payload : JSON.stringify(payload);
  const findings = [];
  for (const entry of sensitivePatterns) {
    const pattern = new RegExp(entry.pattern.source, entry.pattern.flags);
    if (pattern.test(text)) {
      findings.push(entry.name);
    }
  }
  return findings;
}
