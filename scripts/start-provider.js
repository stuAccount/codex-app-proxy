import process from "node:process";

const providerName = process.argv[2]?.trim();

if (!providerName) {
  console.error("Usage: node scripts/start-provider.js <provider>");
  process.exit(1);
}

process.env.ACTIVE_PROVIDER = providerName;
await import("../src/server.js");
