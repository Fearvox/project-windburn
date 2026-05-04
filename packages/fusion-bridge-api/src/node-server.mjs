import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createFusionBridgeApi } from "./api.mjs";

const packageDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const defaultRoot = path.resolve(packageDir, "../..");

async function loadJson(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
}

export function createNodeFusionBridgeApi(options = {}) {
  const root = options.root ?? defaultRoot;
  const fixturePath = options.fixturePath ??
    path.join(root, "docs/remote-workhorse/fixtures/superruntime-v0.json");
  return createFusionBridgeApi({
    deploymentTarget: "node-http",
    superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
    loadSuperruntimeFixture: () => loadJson(fixturePath),
    serviceVersion: options.serviceVersion,
  });
}

export function startNodeFusionBridgeApi(options = {}) {
  const host = options.host ?? process.env.WINDBURN_BRIDGE_API_HOST ?? "127.0.0.1";
  const port = Number(options.port ?? process.env.WINDBURN_BRIDGE_API_PORT ?? "5188");
  const api = createNodeFusionBridgeApi(options);
  const server = createServer(async (request, response) => {
    const apiResponse = await api.fetch(new Request(`http://${host}:${port}${request.url}`, {
      method: request.method,
      headers: request.headers,
    }));
    response.writeHead(apiResponse.status, Object.fromEntries(apiResponse.headers));
    if (request.method === "HEAD") {
      response.end();
      return;
    }
    response.end(Buffer.from(await apiResponse.arrayBuffer()));
  });

  return new Promise((resolve) => {
    server.listen(port, host, () => {
      resolve({ server, host, port });
    });
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const { host, port } = await startNodeFusionBridgeApi();
  console.log(`windburn_fusion_bridge_api_url=http://${host}:${port}`);
  console.log("mode=read-only-api");
  console.log("mutation_bridge_enabled=false");
}
