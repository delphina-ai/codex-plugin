---
name: setup
description: Set up Delphina in Codex — check the connection, sign in, pick a workspace, and optionally sync the knowledge base. Use when the user asks to set up, connect, or check Delphina, or when a Delphina tool is missing or asks for sign-in.
---

# Set up Delphina

Walks someone from "the plugin is installed" to "it works." Everything past the
connection check is optional, so ask before each part rather than doing all of
it — most people want one thing.

## 1. Check the connection

Call `list_workspaces`.

- **It returns workspaces** — connected. Show them the list and move on.
- **It says the account is not enabled for MCP access** — their organization has
  not turned the Delphina MCP server on. That is an administrator setting; tell
  them who to ask rather than trying to work around it.
- **The tool does not exist** — Codex has not signed in to Delphina yet, or the
  plugin is not loaded. Ask them to check from a shell:

  ```bash
  codex mcp list
  ```

  If `delphina` shows as not logged in, they sign in with the command below,
  which opens a browser. Then they start a new Codex session; tools are loaded
  when a session starts.

  ```bash
  codex mcp login delphina
  ```

  If `delphina` is missing from the list, the plugin is not installed:
  `codex plugin add delphina@delphina`, then a new session.

Do not run either command yourself. Sign-in happens in their browser, and the
sandbox blocks the network these commands need.

If a single workspace comes back, or one is marked `is_default`, say which one
you will use. If several could plausibly match what they work on, ask.

## 2. Offer the knowledge base

Ask whether they want their team's metric, table and rule definitions available
locally. If yes, follow the `sync-knowledge` skill.

Worth saying: it makes definition questions answerable without a round trip, and
the copy is read-only — editing the files changes nothing in Delphina.

Mention that the download needs network access, so Codex will ask them to
approve it. They can save the approval so later syncs do not ask again.

## Trace capture

The Claude Code plugin can upload Delphina sessions to improve the team's
knowledge base. The Codex plugin cannot yet. If they ask, say so; do not try to
set it up by hand.
