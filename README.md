# Claude Code Supervisor — Installer

Signed binary distribution for the [Claude Code Supervisor](https://claude-code-supervisor.vercel.app) team telemetry watcher.

## Install (macOS only)

You need:
- macOS
- Node.js 22+
- A Claude Code account that's in the **company allowlist** (ask Dion)
- The `INGEST_TOKEN` (ask Dion)

One-liner:

```bash
INGEST_TOKEN=<paste-from-admin> \
  curl -fsSL https://raw.githubusercontent.com/potenlab/cc-supervisor-installer/main/install.sh | bash
```

The installer:
1. Downloads `cc-supervisor-watcher.js` (≈190 KB)
2. Verifies the SHA-256 checksum
3. Drops `~/.cc-supervisor/watcher.env`
4. Installs the `com.cc-supervisor.watcher` LaunchAgent

Once installed, log in to Claude Code with a **company** account. The watcher auto-detects via Apple Keychain and starts shipping telemetry. Personal accounts → ingest paused.

## Verify

```bash
tail -f ~/.cc-supervisor/watcher.log
```

Look for:

```
[cc-supervisor] account=<your-company-email> sub=max
[cc-supervisor] config: monitor-all · company-accounts=3
[cc-supervisor] usage 5h=X% 7d=Y% ...
```

## Update

Just re-run the install command — fetches latest binary, verifies fresh sha, reloads the agent.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/potenlab/cc-supervisor-installer/main/uninstall.sh | bash
```

## What gets shipped

Only when the active Claude account is in the company allowlist:
- Prompt previews (first 500 chars), assistant reply text (first 500 chars)
- Token usage per assistant message (input/output/cache)
- Model name, session id, project path
- `/usage` utilization snapshots (5h, 7d, per-model)

Never:
- OAuth tokens, API keys
- Personal account activity (gated server-side and watcher-side)

Source code is private. See https://claude-code-supervisor.vercel.app for the dashboard.
