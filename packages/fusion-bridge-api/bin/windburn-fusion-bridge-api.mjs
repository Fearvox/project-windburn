#!/usr/bin/env node
import { startNodeFusionBridgeApi } from "../src/node-server.mjs";

const { host, port } = await startNodeFusionBridgeApi();
console.log(`windburn_fusion_bridge_api_url=http://${host}:${port}`);
console.log("mode=read-only-api");
console.log("mutation_bridge_enabled=false");
