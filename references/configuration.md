# OpenClaw Configuration Reference

> Always check https://docs.openclaw.ai/configuration for the latest schema. OpenClaw evolves rapidly.

## Table of Contents

- [File Locations](#file-locations)
- [Environment Variables](#environment-variables)
- [Gateway Settings](#gateway-settings)
- [Agent Defaults](#agent-defaults)
- [Memory](#memory)
- [Models](#models)
- [Skills](#skills)
- [Plugins](#plugins)
- [Browser](#browser)
- [Commands](#commands)
- [Tools Configuration](#tools-configuration)
- [Session Management](#session-management)
- [Messages & Streaming](#messages--streaming)
- [Talk/Voice](#talkvoice)
- [Environment](#environment)
- [Channel Configuration](#channel-configuration) (WhatsApp, Telegram, Discord, Slack, Signal, iMessage, Google Chat, Mattermost, others)
- [Logging](#logging)
- [Config Includes](#config-includes)
- [Diagnostic Commands](#diagnostic-commands)

## File Locations

| File | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Primary config (JSON5) |
| `~/.openclaw/.env` | Global env vars |
| `.env` (cwd) | Local env vars (higher priority) |
| `~/.openclaw/agents/<id>/agent/auth-profiles.json` | Per-agent model auth |
| `~/.openclaw/agents/<id>/sessions/` | Session storage |
| `~/.openclaw/memory/<agentId>.sqlite` | Vector index for memory search |
| `<workspace>/memory/YYYY-MM-DD.md` | Daily memory logs (in agent workspace) |
| `<workspace>/MEMORY.md` | Long-term memory (in agent workspace) |
| `~/.openclaw/workspace` | Default workspace |
| `~/.openclaw/sandboxes` | Sandbox workspaces |
| `~/.openclaw/skills` | Workspace skills |
| `~/.openclaw/extensions` | Plugins |
| `/tmp/openclaw/openclaw-YYYY-MM-DD.log` | Logs |

## Environment Variables

### API Keys (use env vars, NOT config file)

| Provider | Env Var |
|----------|---------|
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Google/Gemini | `GOOGLE_API_KEY` / `GEMINI_API_KEY` |
| AWS Bedrock | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_REGION` |
| OpenRouter | `OPENROUTER_API_KEY` |
| Groq | `GROQ_API_KEY` |
| MiniMax | `MINIMAX_API_KEY` |
| xAI (Grok) | `XAI_API_KEY` |
| Z.AI | `ZAI_API_KEY` |
| Moonshot | `MOONSHOT_API_KEY` |
| Cerebras | `CEREBRAS_API_KEY` |
| Baidu Qianfan | `QIANFAN_API_KEY` |

### Channel Tokens (use env vars, NOT config file)

- `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`
- `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`
- `GOOGLE_CHAT_SERVICE_ACCOUNT_FILE`
- `MATTERMOST_BOT_TOKEN`, `MATTERMOST_URL`

### Core
- `OPENCLAW_STATE_DIR` — config/data root (default: `~/.openclaw`)
- `OPENCLAW_HOME` — override home directory for internal path resolution (v2026.2.9+)
- `OPENCLAW_GATEWAY_TOKEN` — gateway auth token
- `OPENCLAW_AGENT_DIR` — agent directory override
- `BRAVE_API_KEY` — web search
- `FIRECRAWL_API_KEY` — web scraping
- `ELEVENLABS_API_KEY` — TTS

## Gateway Settings

```json5
{
  gateway: {
    mode: "local",              // "local" or "remote"
    bind: "loopback",           // "loopback"/"lan"/"tailnet"/"custom"
    port: 18789,
    auth: {
      mode: "token",            // "token", "password", or "none" (v2026.2.19+)
      token: "your-secret",
      allowTailscale: false,
    },
    customBindHost: "0.0.0.0",  // Only valid when bind="custom" (v2026.2.19+)
    channelHealthCheckMinutes: 5, // Strict validation (v2026.2.19+)
    trustedProxies: [],         // For reverse proxy setups
    controlUi: {
      allowInsecureAuth: false,
      dangerouslyDisableDeviceAuth: false,
    },
  },
}
```

## Agent Defaults

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: { primary: "anthropic/claude-sonnet-4-5", fallbacks: [] },
      thinkingDefault: "low",       // "low"/"high"/"off"
      maxConcurrent: 1,
      timeoutSeconds: 600,
      userTimezone: "Asia/Taipei",
      sandbox: { mode: "non-main" },

      // Memory & search
      memorySearch: {
        provider: "openai",         // "local"/"openai"/"gemini"/"voyage"/"disabled"
        model: "text-embedding-3-small",
        local: { modelPath: "hf:..." },
        extraPaths: ["~/notes"],    // Index external Markdown dirs
      },
      compaction: {
        reserveTokens: 8000,      // Tokens to reserve for response (v2026.2.19+)
        keepRecentTokens: 4000,   // Recent tokens to keep uncompacted (v2026.2.19+)
      },

      // Streaming & typing
      blockStreamingDefault: "off",    // "on"/"off"
      blockStreamingBreak: "text_end", // "text_end"/"message_end"
      blockStreamingChunk: { minChars: 100, maxChars: 500 },
      blockStreamingCoalesce: {},      // Merge streamed blocks
      humanDelay: { mode: "off" },     // "off"/"natural"/"custom"
      typingMode: "thinking",          // "never"/"instant"/"thinking"/"message"
      typingIntervalSeconds: 6,

      // Context & subagents
      contextPruning: { mode: "adaptive" }, // "adaptive"/"aggressive"/"off"
      subagents: {
        model: "anthropic/claude-haiku-4-5",
        maxConcurrent: 8,
        archiveAfterMinutes: 30,
        maxSpawnDepth: 2,         // Nested subagent depth limit (v2026.2.15+)
      },
    },
    list: [
      {
        id: "main",
        name: "Main Agent",
        default: true,
        identity: {
          name: "Claw",
          theme: "default",
          emoji: "🦞",
          avatar: "url",
        },
      },
    ],
  },
}
```

## Memory

```json5
{
  memory: {
    citations: "auto",              // "auto"/"on"/"off"
  },
}
```

Memory uses hybrid BM25 + vector search. Auto-flushes before context compaction.

## Models

```json5
{
  models: {
    mode: "merge",  // "merge"/"replace" — merge with or replace built-in providers
    providers: {
      "custom": {
        baseUrl: "https://api.example.com/v1",
        apiKey: "$MY_API_KEY",
        models: [],
      },
    },
  },
}
```

## Skills

```json5
{
  skills: {
    entries: {
      "skill-name": {
        enabled: true,
        apiKey: "secret",
        env: { VAR: "value" },
        config: { key: "value" },
      },
    },
    load: {
      watch: true,
      watchDebounceMs: 250,
      extraDirs: ["/path/to/skills"],
    },
    allowBundled: ["skill1", "skill2"],
    install: {
      preferBrew: true,
      nodeManager: "pnpm",
    },
  },
}
```

Skills are loaded from: bundled (lowest) → `~/.openclaw/skills` → `<workspace>/skills` (highest). Each skill adds ~24 tokens to system prompt.

## Plugins

```json5
{
  plugins: {
    enabled: true,
    allow: ["plugin-a"],
    deny: ["plugin-b"],
    load: { paths: ["/extra/plugins"] },
    entries: {
      "plugin-name": { enabled: true, config: {} },
    },
  },
}
```

## Browser

```json5
{
  browser: {
    enabled: true,
    evaluateEnabled: true,
    ssrfPolicy: "strict",       // SSRF validation policy (v2026.2.19+)
    extraArgs: [],              // Custom Chrome launch arguments (v2026.2.17+)
    profiles: {
      "agent": { cdpUrl: "ws://..." },
    },
  },
}
```

## Commands

```json5
{
  commands: {
    native: "auto",       // "auto"/true/false
    text: true,           // Parse slash commands in messages
    bash: false,          // Allow ! for shell commands
    bashForegroundMs: 2000,
    config: false,        // Allow /config command
    debug: false,         // Allow /debug command
    restart: false,       // Allow /restart command
    useAccessGroups: true,
  },
}
```

## Tools Configuration

```json5
{
  tools: {
    profile: "coding",               // "minimal"/"coding"/"messaging"/"full"
    allow: ["read_*", "write_*", "exec"],
    deny: ["browser"],               // Deny wins
    elevated: {
      enabled: true,
      allowFrom: { whatsapp: ["+886..."] },
    },
    exec: { backgroundMs: 10000, timeoutSec: 1800 },
    web: {
      search: { enabled: true, maxResults: 5, urlAllowlist: [] },  // URL allowlist (v2026.2.17+)
      fetch: { enabled: true, maxChars: 50000, urlAllowlist: [] }, // URL allowlist (v2026.2.17+)
    },
    media: { image: { enabled: true }, audio: { enabled: true } },
    agentToAgent: { enabled: false },
  },
}
```

## Session Management

```json5
{
  session: {
    scope: "per-sender",
    dmScope: "per-peer",              // "main"/"per-peer"/"per-channel-peer"
    mainKey: "main",                  // Primary DM bucket key
    store: "~/.openclaw/agents/{agentId}/sessions",
    reset: { mode: "daily", atHour: 4 },
    resetByType: {},                  // Per-session-type overrides (dm, group, thread)
    resetTriggers: ["/new", "/reset"],
    identityLinks: [
      { whatsapp: "+886...", telegram: "tg:..." },
    ],
    agentToAgent: { maxPingPongTurns: 5 },
    sendPolicy: {},                   // Per-channel/chatType routing
  },
}
```

## Messages & Streaming

```json5
{
  messages: {
    responsePrefix: "",
    ackReaction: "👀",
    ackReactionScope: "group-mentions", // "group-mentions"/"group-all"/"direct"/"all"
    removeAckAfterReply: false,
    queue: { mode: "steer", debounceMs: 1000 },
    tts: { auto: "off", provider: "elevenlabs" },
    groupChat: {
      historyLimit: 20,
      requireMention: true,
    },
    inbound: {
      debounceMs: 1000,
      byChannel: {},
    },
  },
}
```

## Talk/Voice

```json5
{
  talk: {
    voiceId: "elevenlabs-voice-id",
    voiceAliases: { "friendly": "voice-id" },
    modelId: "eleven_v3",
    apiKey: "$ELEVENLABS_API_KEY",
    interruptOnSpeech: false,
  },
}
```

## Environment

```json5
{
  env: {
    shellEnv: {
      enabled: true,
      timeoutMs: 5000,
    },
  },
}
```

## Channel Configuration

### WhatsApp
```json5
{
  channels: {
    whatsapp: {
      dmPolicy: "pairing",
      allowFrom: ["+886912345678"],           // E.164 format
      groups: {
        "*": { requireMention: true },
        "group-jid@g.us": { requireMention: false },
      },
      sendReadReceipts: true,
      textChunkLimit: 4000,
      mediaMaxMb: 50,
      accounts: { personal: {}, biz: {} },    // Multi-account
    },
  },
}
```

### Telegram
```json5
{
  channels: {
    telegram: {
      // botToken: use TELEGRAM_BOT_TOKEN env var
      dmPolicy: "pairing",
      allowFrom: ["tg:123456789"],
      groups: { "-1001234567890": { requireMention: true } },
      streamMode: "partial",          // "off"/"partial"/"block"
      buttonStyle: true,              // Inline button styles: primary/success/danger (v2026.2.17+)
      reactionNotifications: "off",   // "off"/"own"/"all" — user reaction events (v2026.2.17+)
      voiceNoteTranscription: true,   // DM voice-note transcription (v2026.2.19+)
      historyLimit: 50,
      mediaMaxMb: 5,
      customCommands: [],             // Bot menu commands
      replyToMode: "off",             // "off"/"first"/"all"
      linkPreview: true,
      draftChunk: { minChars: 100, maxChars: 500, breakPreference: "text_end" },
      retry: { attempts: 3, minDelayMs: 1000, maxDelayMs: 5000, jitter: true },
      proxy: "socks5://...",
      webhookUrl: "https://...",
      webhookSecret: "...",
      accounts: {},                   // Multi-account
      configWrites: true,             // Allow Telegram to trigger config updates
    },
  },
}
```

### Discord
```json5
{
  channels: {
    discord: {
      // token: use DISCORD_BOT_TOKEN env var
      dm: { enabled: true, policy: "pairing" },
      guilds: {
        "guild-id": {
          channels: ["channel-id-1"],
          requireMention: true,
        },
      },
      historyLimit: 20,
      textChunkLimit: 2000,
      maxLinesPerMessage: 17,
      chunkMode: "length",            // "length"/"newline"
      allowBots: false,
      replyToMode: "off",             // "off"/"first"/"all"
      actions: {                      // Tool action gates
        reactions: true,
        stickers: true,
        polls: true,
        moderation: false,
      },
      components: {                   // Components v2: interactive elements (v2026.2.15+)
        enabled: true,
        allowedUsers: [],             // Per-button user allowlist
      },
    },
  },
}
```

### Slack
```json5
{
  channels: {
    slack: {
      // botToken/appToken: use env vars
      dm: { policy: "pairing" },
      channels: { "C01234567": {} },
      historyLimit: 50,
      reactionNotifications: "off",   // "off"/"own"/"all"/"allowlist"
      reactionAllowlist: [],          // User IDs
      replyToMode: "off",             // "off"/"first"/"all"
      thread: {
        historyScope: "thread",
        inheritParent: false,
      },
      streaming: {                    // Native streaming via chat.startStream (v2026.2.19+)
        enabled: false,
        mode: "draft",              // "draft"/"live"
      },
      slashCommand: {
        enabled: true,
        name: "/claw",
        ephemeral: false,
      },
      actions: {},                    // Tool action gates
    },
  },
}
```

### Signal
```json5
{
  channels: {
    signal: {
      // Linked device model
      reactionNotifications: "off",   // "off"/"own"/"all"/"allowlist"
      reactionAllowlist: [],          // Phone/UUID array
    },
  },
}
```

### iMessage
```json5
{
  channels: {
    imessage: {
      cliPath: "imsg",                // Path to imsg binary
      dbPath: "~/Library/Messages/chat.db",
      remoteHost: "user@host",        // SSH for remote attachments
      includeAttachments: false,
      service: "auto",                // "auto"/"iMessage"/"SMS"/"FaceTime Audio"
      region: "US",                   // "US"/"GB"/etc.
    },
  },
}
```

### Google Chat
```json5
{
  channels: {
    googleChat: {
      serviceAccountFile: "$GOOGLE_CHAT_SERVICE_ACCOUNT_FILE",
      audienceType: "pubsub",
      audience: "...",
      webhookPath: "/webhook/google-chat",
      botUser: "bot@project.iam",
      dm: { policy: "pairing" },
      groups: {},
      mediaMaxMb: 25,
    },
  },
}
```

### Mattermost
```json5
{
  channels: {
    mattermost: {
      baseUrl: "$MATTERMOST_URL",
      chatmode: "oncall",             // "oncall"/"onmessage"/"onchar"
      oncharPrefixes: ["@bot", "!"],
      emojiReactions: true,           // Emoji reactions + event notifications (v2026.2.17+)
    },
  },
}
```

### BlueBubbles
```json5
{
  channels: {
    bluebubbles: {
      serverUrl: "http://localhost:1234",
      password: "$BLUEBUBBLES_PASSWORD",
      dmPolicy: "pairing",
    },
  },
}
```

### Other Channels
- **Teams**: Enterprise integration. See docs.
- **LINE**: OAuth-based. See docs.
- **Matrix**: Homeserver config. See docs.
- **Feishu**: App credentials. See docs.
- **Zalo**: Multi-account, OA support. See docs.

## Logging

```json5
{
  logging: {
    level: "info",
    consoleLevel: "info",
    consoleStyle: "pretty",           // "pretty"/"compact"/"json"
    redactSensitive: "tools",         // "off" or "tools"
    redactPatterns: ["INTERNAL_\\w+"],
  },
}
```

## Config Includes

```json5
{
  gateway: { port: 18789 },
  agents: { $include: "./agents.json5" },
  channels: { $include: ["./wa.json5", "./tg.json5"] },
}
```

Max 10 nesting levels. Later includes override earlier. Sibling keys override includes.

## Diagnostic Commands

| Command | Purpose |
|---------|---------|
| `openclaw doctor [--fix]` | Validate config, auto-repair |
| `openclaw health` | Gateway health status |
| `openclaw status [--all]` | Full state (secrets redacted) |
| `openclaw config get` | Fetch config + hash |
| `openclaw config set <key> <val>` | Partial update |
| `openclaw logs` | View recent logs |
| `openclaw security audit [--deep] [--fix]` | Security review |
| `openclaw memory` | Memory index status |
| `openclaw skills` | List loaded skills |
| `openclaw cron` | Scheduled tasks status |
| `openclaw browser` | Browser session info |
| `openclaw sandbox` | Sandbox workspaces |
| `openclaw models` | Available models |
| `openclaw sessions` | Active sessions |
| `openclaw nodes` | Agent node tree |
| `openclaw plugins` | Plugin registry |
| `openclaw devices` | Paired device management |
| `openclaw devices remove <id>` | Remove paired device |
| `openclaw devices clear --yes` | Clear all paired devices |
| `openclaw cron add --stagger` | Staggered cron scheduling |
| `openclaw acp` | Agent Control Protocol tools |
| `openclaw hooks` | Manage internal agent hooks |
| `openclaw onboard` | Interactive onboarding wizard |
| `openclaw dashboard` | Open Control UI |
| `openclaw dns` | DNS helpers (Tailscale + CoreDNS) |
| `openclaw directory` | Lookup contact/group IDs |
