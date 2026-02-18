# Use the official Node.js image as a base
FROM node:20-alpine

RUN apk add git bash curl

# Set the working directory
WORKDIR /app

COPY review-template.html .

# Install the Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g marked

# Claude Code default settings
RUN mkdir -p /root/.claude && cat > /root/.claude/settings.json <<'EOF'
{
  "enabledPlugins": {
    "gopls-lsp@claude-plugins-official": true,
    "swift-lsp@claude-plugins-official": true
  },
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "includeCoAuthoredBy": false,
  "permissions": {
    "deny": [
      "Read(**/.env)",
      "Bash(sudo:*)",
      "Bash(su:*)",
      "Bash(ssh:*)"
    ]
  },
  "language": "Russian",
  "autoUpdatesChannel": "latest",
  "gitAttribution": false,
  "env": {
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
    "DISABLE_TELEMETRY": 1,
    "DISABLE_ERROR_REPORTING": 1
  }
}
EOF


# (Optional) Set the default command to start an interactive session
CMD ["claude-code"]
