#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import {
  setupServerTool,
  handleSetupServer,
} from "./tools/configure-server.js";
import { listAppsTool, handleListApps } from "./tools/list-apps.js";
import { deployAppTool, handleDeployApp } from "./tools/deploy-app.js";
import {
  deployCustomAppTool,
  handleDeployCustomApp,
} from "./tools/deploy-custom-app.js";
import {
  serverStatusTool,
  handleServerStatus,
} from "./tools/server-status.js";

const server = new Server(
  { name: "mikrus-toolbox", version: "0.2.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    setupServerTool,
    listAppsTool,
    deployAppTool,
    deployCustomAppTool,
    serverStatusTool,
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "setup_server":
      return handleSetupServer(args ?? {});
    case "list_apps":
      return handleListApps(args ?? {});
    case "deploy_app":
      return handleDeployApp(args ?? {});
    case "deploy_custom_app":
      return handleDeployCustomApp(args ?? {});
    case "server_status":
      return handleServerStatus(args ?? {});
    default:
      return {
        content: [{ type: "text", text: `Unknown tool: ${name}` }],
        isError: true,
      };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  process.stderr.write(`MCP server error: ${err}\n`);
  process.exit(1);
});
