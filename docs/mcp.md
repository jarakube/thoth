# MCP Servers

Both agents in this container support remote MCP servers over the
streamable-http transport:

- **OpenCode**: `opencode mcp add <name> --url <url>` (stored in the OpenCode
  config, e.g. `~/.config/opencode/opencode.jsonc`)
- **Goose**: `mcp_servers` in `~/.config/goose/config.yaml` (or
  `goose configure` → Add Extension → Remote Extension (Streamable HTTP))

## Example: the Jarakube website MCP server

The container entrypoint registers a public example MCP server for both
agents on first start (opt-out via `MCP_EXAMPLE_ENABLED=0`):

```
https://jarakube.eu/mcp
```

It is operated by [jarakube.eu](https://jarakube.eu), the sovereign
Kubernetes platform that also maintains and supports this project, and
serves the Jaraco GmbH website content: services, blog posts, categories,
and Jarakube platform resources, plus a `draft_email` tool. It requires no
authentication.

### What gets configured

OpenCode (via `opencode mcp add`):

```bash
opencode mcp add jarakube-website --url https://jarakube.eu/mcp
```

Goose (`~/.config/goose/config.yaml`):

```yaml
mcp_servers:
  jarakube-website:
    url: https://jarakube.eu/mcp
```

### Verify

```bash
# OpenCode: list configured MCP servers and their status
opencode mcp list

# Goose: check the extension is loaded (requires a configured provider)
goose doctor
```

Then ask either agent something like "list the available Jarakube website
resources" - the MCP tools/resources appear alongside the built-in tools.

## Adding your own MCP servers

### OpenCode

```bash
# remote server
opencode mcp add my-server --url https://mcp.example.com

# remote server with auth header
opencode mcp add my-server --url https://mcp.example.com \
  --header "Authorization=Bearer $MY_TOKEN"

# local stdio server
opencode mcp add my-server --env KEY=value -- my-command arg1
```

### Goose

```yaml
# ~/.config/goose/config.yaml
mcp_servers:
  my-server:
    url: https://mcp.example.com
    # auth:
    #   type: bearer   # token from keyring/env
```

Or interactively: `goose configure` → Add Extension → Remote Extension
(Streamable HTTP).

## Environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MCP_EXAMPLE_ENABLED` | Set `0` to skip registering the example server | `1` |
| `MCP_EXAMPLE_NAME` | Name used for the example server registration | `jarakube-website` |
| `MCP_EXAMPLE_URL` | URL of the example server | `https://jarakube.eu/mcp` |
