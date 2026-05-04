export const openapi = {
  openapi: "3.1.0",
  info: {
    title: "Windburn Fusion Bridge API",
    version: "0.1.0",
    summary: "Read-only, stream-safe API for Windburn Superruntime status.",
  },
  servers: [
    { url: "http://127.0.0.1:5188", description: "local API package bridge" },
    { url: "http://127.0.0.1:5178", description: "local Fusion Chat bridge" },
    { url: "https://windburn-fusion-bridge.example.workers.dev", description: "Cloudflare Worker package target" },
  ],
  paths: {
    "/healthz": {
      get: {
        operationId: "getHealth",
        summary: "API health and policy metadata",
        responses: { "200": { description: "Read-only API health" } },
      },
    },
    "/api/status": {
      get: {
        operationId: "getStatus",
        summary: "Read-only service status",
        responses: { "200": { description: "Bridge status" } },
      },
    },
    "/api/superruntime": {
      get: {
        operationId: "getSuperruntime",
        summary: "Stream-safe Superruntime runtime/task/lease view",
        responses: { "200": { description: "Redacted Superruntime state" } },
      },
    },
    "/openapi.json": {
      get: {
        operationId: "getOpenApi",
        summary: "OpenAPI contract",
        responses: { "200": { description: "OpenAPI 3.1 document" } },
      },
    },
  },
};
