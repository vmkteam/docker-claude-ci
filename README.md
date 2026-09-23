# claude-ci

Docker image for AI code review in CI/CD (the base of the
[vmkteam/reviewer](https://github.com/vmkteam/reviewer) CI image). Published as
`vmkteam/claude-ci` and `ghcr.io/vmkteam/docker-claude-ci` on every GitHub release.

## Contents

| Tool | Version (`ARG`) | Notes |
|---|---|---|
| [Claude Code](https://code.claude.com) | `CLAUDE_CODE_VERSION` | npm install; `gopls-lsp` plugin pre-installed |
| [Codex CLI](https://github.com/openai/codex) | `CODEX_VERSION` | npm install |
| [opencode](https://opencode.ai) | `OPENCODE_VERSION` | npm install, musl binary only |
| Go + [gopls](https://go.dev/gopls) | `GO_VERSION`, `GOPLS_VERSION` | for the LSP plugin and `go build/vet/test` |
| [marked](https://marked.js.org) | `MARKED_VERSION` | npm install; `review-template.html` in `/app` |
| git, bash, curl, ripgrep | — | Alpine packages |

Base: `node:24-alpine`, linux/amd64. Versions are pinned — nothing auto-updates at
runtime (Claude Code's auto-updater is off, `OPENCODE_DISABLE_AUTOUPDATE=1`); bump the
`ARG`s in the `Dockerfile` and publish a release.

## Claude Code settings

`/root/.claude/settings.json`: Russian `language`, `Concise` output style, no commit/PR
attribution, auto-updater and telemetry off, system ripgrep (`USE_BUILTIN_RIPGREP=0`,
required on musl), no claude.ai plugin sync, and `deny` rules for `.env` reads,
`sudo`/`su`/`ssh`, `git push` and `git commit` (deny rules apply even with
`--permission-mode bypassPermissions`).

## Sandboxing

The container runs as root and is itself the sandbox:

- **Claude Code** refuses `--permission-mode bypassPermissions` (reviewctl always passes
  it) as root — `--dangerously-skip-permissions cannot be used with root/sudo privileges`.
  The image sets `IS_SANDBOX=1`, which lifts that check; the `deny` rules above still apply.
- **Codex**'s Linux sandbox (bubblewrap) needs unprivileged user namespaces, which an
  unprivileged Docker container doesn't have — `--sandbox workspace-write`/`read-only`
  fail with `bwrap: No permissions to create a new namespace`. Run codex with
  `--sandbox danger-full-access` instead. reviewctl does this when
  `REVIEW_CODEX_SANDBOX=danger-full-access` is set — the reviewer CI Dockerfile
  (admin → CI Setup) sets it on top of this image.

## Build

```sh
docker build --platform linux/amd64 -t claude-ci .
```
