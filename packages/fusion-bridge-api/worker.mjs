import fixture from "../../docs/remote-workhorse/fixtures/superruntime-v0.json" with { type: "json" };
import { createFusionBridgeApi } from "./src/api.mjs";

const api = createFusionBridgeApi({
  deploymentTarget: "cloudflare-worker",
  serviceVersion: "0.1.0",
  superruntimeFixture: fixture,
  superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
});

export default {
  fetch(request) {
    return api.fetch(request);
  },
};
