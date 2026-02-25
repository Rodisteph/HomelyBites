import "dotenv/config";
import { Agent, Runner } from "@openai/agents";
import fs from "node:fs";

function load(path: string) {
  return fs.readFileSync(new URL(path, import.meta.url), "utf8");
}

const backendAuditor = new Agent({
  name: "BackendAuditor",
  instructions: load("./instructions/backend_auditor.md"),
});

const frontendBuilder = new Agent({
  name: "FrontendBuilderSwiftUI",
  instructions: load("./instructions/frontend_builder.md"),
});

const productPM = new Agent({
  name: "ProductPM_QA",
  instructions: load("./instructions/product_pm.md"),
});

// Router simple: choisit l’agent selon un tag
// Usage: npm run agent -- backend "ton message"
async function main() {
  const [, , agentKey, ...rest] = process.argv;
  const input = rest.join(" ").trim();
  if (!agentKey || !input) {
    console.log('Usage:\n  npm run agent -- backend "message"\n  npm run agent -- frontend "message"\n  npm run agent -- pm "message"');
    process.exit(1);
  }

  const agent =
    agentKey === "backend" ? backendAuditor :
    agentKey === "frontend" ? frontendBuilder :
    agentKey === "pm" ? productPM :
    null;

  if (!agent) {
    console.error("Agent inconnu. Utilise: backend | frontend | pm");
    process.exit(1);
  }

  const runner = new Runner();
  const result = await runner.run(agent, input);
  console.log("\n=== RESPONSE ===\n");
  console.log(result.finalOutput ?? result);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
