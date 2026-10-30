# Delphina for Codex

Ask [Delphina](https://delphina.ai)'s analytics agent data questions without leaving
Codex. This plugin bundles the Delphina MCP server configuration, so connecting is
a few commands instead of hand-editing `config.toml`.

Once installed, Codex can start a Delphina chat, send follow-up messages, pull
back results, and file issues — the same agent you get in the web app and in
Slack. Delphina answers using your team's warehouse and curated knowledge base;
Codex sees the answers, not the underlying data.

It can also sync your **knowledge base** — the curated metrics, tables, notes, and
rules Delphina reasons over — to a local folder, so Codex can grep your team's
definitions directly instead of asking one question at a time. See
[Knowledge sync](#knowledge-sync).

> **Beta.** The Delphina MCP server is in beta and must be enabled for your
> organization. Ask your Delphina administrator if you are not sure whether you
> have access.

Using Claude Code? Install [`delphina-ai/claude-plugin`](https://github.com/delphina-ai/claude-plugin)
instead.

## Install

```bash
codex plugin marketplace add delphina-ai/codex-plugin
codex plugin add delphina@delphina
codex mcp login delphina
```

The last command opens a browser to sign in to Delphina, and Codex stores the
OAuth credential for you. Then start a new Codex session and ask it to "set up
Delphina", which checks the connection and offers the knowledge base.

### Keeping it up to date

Codex does not update plugins on its own. To pick up a new release:

```bash
codex plugin marketplace upgrade delphina
codex plugin add delphina@delphina
```

Then start a new session.

## Knowledge sync

Ask Codex to "sync the Delphina knowledge base" (or just ask a question about
your metrics) and it will pull a snapshot to
`.delphina/knowledge/<workspace-id>/` — one markdown file per document, laid out
as `<namespace>/<type>/<name>.md`.

You do not have to say which workspace. Codex syncs your default one, and can
call `list_workspaces` to show you the alternatives if you have more than one.

The download needs network access, which Codex's default sandbox blocks, so
Codex asks you to approve it. You can save that approval for the download
script, and later syncs will not ask again until the plugin is updated.

From then on Codex answers definition questions by reading those files, with no
round-trip to Delphina. The cache is git-ignored automatically, so it never lands
in your repository.

Syncs are pinned to a snapshot id and are free when nothing has changed: Codex
sends back the id it already has, and an unchanged knowledge base transfers no
bytes at all. Sync once per session; the snapshot is read-only, and editing the
files changes nothing in Delphina.

Each snapshot declares the directory layout it uses, and the plugin refuses one
it does not understand rather than extracting a tree it would then look for in
the wrong place. If that happens, update the plugin — the error says how.

## Trace capture

Not available in the Codex plugin yet. The Claude Code plugin can upload
sessions that used Delphina to improve your team's knowledge base; the Codex
version is planned for a later release.

## Configuration

The plugin points at Delphina's production MCP server,
`https://app.delphina.ai/api/mcp`. That is the right value for essentially
everyone, and there is nothing to configure.

If Delphina gave you a different URL for your deployment, override it in
`~/.codex/config.toml`:

```toml
[mcp_servers.delphina]
url = "https://your-host.example.com/api/mcp"
```

Or for a single run: `codex -c 'mcp_servers.delphina.url="https://your-host.example.com/api/mcp"'`.

### Authorizing without OAuth

OAuth is preferred: there is no long-lived key to copy around, and access follows
your Delphina account. If you are in an environment that cannot complete a browser
sign-in — CI, a headless container — use an API key instead.

In Delphina, go to **Settings → Connect to Delphina MCP → General**, expand
**API Key Authorization**, and copy the key. Put it in an environment variable,
without the `Bearer ` prefix, and point the server at it:

```bash
export DELPHINA_API_KEY=YOUR_API_KEY
codex mcp add delphina --url https://app.delphina.ai/api/mcp \
  --bearer-token-env-var DELPHINA_API_KEY
```

Treat that key like a password. Do not commit it.

## What's in here

This repository is both a Codex plugin and a single-plugin marketplace:

| Path                               | Purpose                                                        |
| ---------------------------------- | -------------------------------------------------------------- |
| `.codex-plugin/plugin.json`        | Plugin manifest — name, version, and metadata                  |
| `.agents/plugins/marketplace.json` | Marketplace catalog listing this plugin at the repository root |
| `.mcp.json`                        | The Delphina MCP server definition                             |
| `skills/setup/`                    | Connection check, sign-in, and the optional knowledge base     |
| `skills/sync-knowledge/`           | The knowledge-base sync skill                                  |
| `scripts/apply-snapshot.sh`        | Downloads, version-checks, and atomically installs a snapshot  |

This repository started as a copy of `delphina-ai/claude-plugin` at 0.6.0. The
two plugins share server-side contracts — the snapshot layout version, and later
the trace upload API — so a change to one of those ships in both.

## Support

- Docs: <https://docs.delphina.ai/integrations/delphina-mcp>
- Email: <support@delphina.ai>
- Bugs in the plugin itself: open an issue on this repository.

## License

MIT — see [LICENSE](LICENSE).
