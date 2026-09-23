# CI image for AI code review: Claude Code, Codex and opencode CLIs, plus a Go
# toolchain with gopls so Claude Code's gopls-lsp plugin works.
# Bump the pinned versions below deliberately; nothing auto-updates at runtime.
ARG GO_VERSION=1.27

FROM golang:${GO_VERSION}-alpine AS go

# node:24 — Claude Code's npm package requires Node.js 22+.
FROM node:24-alpine

ARG CLAUDE_CODE_VERSION=2.1.281
ARG CODEX_VERSION=0.156.1
ARG OPENCODE_VERSION=1.18.32
ARG GOPLS_VERSION=v0.23.0
ARG MARKED_VERSION=18.0.14

# libgcc/libstdc++/ripgrep are Claude Code's runtime deps on musl (see
# USE_BUILTIN_RIPGREP below); ripgrep lives in the community repository.
RUN apk add --no-cache git bash curl libgcc libstdc++ ripgrep

# Go toolchain (gopls shells out to `go`; also lets the reviewer run go build/vet/test).
COPY --from=go /usr/local/go /usr/local/go
ENV GOPATH=/root/go
ENV PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
RUN go install golang.org/x/tools/gopls@${GOPLS_VERSION} \
    && go clean -cache -modcache \
    && gopls version

# Set the working directory
WORKDIR /app

COPY review-template.html .

# Review runners (Claude Code, Codex, opencode) and marked. claude-code and
# opencode-ai link their native binaries in postinstall scripts; opencode's
# hard-links the one variant it picked into bin/, so the four per-platform
# packages npm pulls in (~700MB) can go.
RUN npm install -g --allow-scripts=@anthropic-ai/claude-code,opencode-ai \
      @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
      @openai/codex@${CODEX_VERSION} \
      opencode-ai@${OPENCODE_VERSION} \
      marked@${MARKED_VERSION} \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/opencode-ai/node_modules/opencode-linux-* \
    && claude --version && codex --version && opencode --version

# The container is the sandbox and runs as root. Claude Code refuses
# --permission-mode bypassPermissions (reviewctl always passes it) as root
# unless IS_SANDBOX=1; opencode would otherwise self-update on startup.
ENV IS_SANDBOX=1 \
    OPENCODE_DISABLE_AUTOUPDATE=1

# Claude Code default settings
RUN mkdir -p /root/.claude && cat > /root/.claude/settings.json <<'EOF'
{
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "permissions": {
    "deny": [
      "Read(**/.env)",
      "Bash(sudo:*)",
      "Bash(su:*)",
      "Bash(ssh:*)",
      "Bash(git push:*)",
      "Bash(git commit:*)"
    ]
  },
  "language": "Russian",
  "outputStyle": "Concise",
  "syncClaudeAiPlugins": false,
  "env": {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_TELEMETRY": "1",
    "DISABLE_ERROR_REPORTING": "1",
    "DISABLE_AUTOUPDATER": "1",
    "USE_BUILTIN_RIPGREP": "0"
  }
}
EOF

# Pre-install the Go LSP plugin (adds it to enabledPlugins) so CI jobs don't
# fetch it at every session start. A fresh HOME has no copy of the official
# marketplace yet, so add it first.
RUN claude plugin marketplace add anthropics/claude-plugins-official \
    && claude plugin install gopls-lsp@claude-plugins-official -y \
    && claude plugin list

CMD ["claude"]
