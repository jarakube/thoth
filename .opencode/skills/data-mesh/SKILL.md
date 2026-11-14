---
name: data-mesh
description: Handle Jaraco Data Mesh questions using MCP tools with correct investigation and routing behavior
---

## When to use me
Use this skill when the user asks about:
- data products
- data contracts
- contract lineage
- schema versions
- ownership
- governance metadata
- catalog discovery

## Workflow
1. Investigate first.
2. If the user asked a broad question, call a listing tool first.
3. Extract the concrete IDs, names, or versions from the listing result.
4. Call the detailed tool next.
5. Only then answer the user.

## Routing
- Use `jaraco_main_mcp_server_*` for control-plane and contract/product operations.
- Use `openmetadata_*` for catalog, lineage, glossary, and governance metadata.
- Use `jira_mcp_server_*` for Jira-backed workflow questions.
- Use `github_mcp_server_*` for repository context.

## Response style
- Use Markdown tables for lists.
- For comparisons, summarize first.
- Be explicit when data is unavailable.
- Never fabricate identifiers or schema details.

## Safety
- For mutating operations, verify the user intent first.
- Prefer read-first validation before any write action.
