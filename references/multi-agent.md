# OpenClaw Multi-Agent & Routing Reference

## Table of Contents

- [Agent Isolation](#agent-isolation)
- [Agent Configuration](#agent-configuration)
- [Subagents](#subagents)
- [Heartbeat](#heartbeat)
- [Routing Priority](#routing-priority-most-specific-first)
- [Bindings](#bindings)
- [Per-Agent Security Profiles](#per-agent-security-profiles)
- [Session Scoping](#session-scoping)
- [Session Send Policy](#session-send-policy)
- [Cross-Channel Identity](#cross-channel-identity)
- [Agent-to-Agent Communication](#agent-to-agent-communication)
- [Group Mention Patterns](#group-mention-patterns)
- [Multi-Account Channels](#multi-account-channels)
- [Security Considerations](#security-considerations)

## Agent Isolation

Each agent is fully isolated:
- Workspace: `~/.openclaw/workspace-<agentId>`
- State dir: `~/.openclaw/agents/<agentId>/agent`
- Auth profiles: per-agent (never share across agents)
- Sessions: `~/.openclaw/agents/<agentId>/sessions`

## Agent Configuration

For `agents.defaults` schema (model, sandbox, workspace, timeout), see [Configuration Reference](configuration.md#agent-defaults).

Multi-agent example with routing identities:

```json5
{
  agents: {
    list: [
      {
        id: "home",
        name: "Home Assistant",
        default: true,
        workspace: "~/.openclaw/workspace-home",
        identity: {
          name: "Claw",        // Display name in messages
          theme: "default",    // UI theme
          emoji: "🦞",         // Icon in message prefix
          avatar: "https://...", // Avatar URL
        },
        groupChat: {
          mentionPatterns: ["@claw", "hey claw"],
        },
      },
      {
        id: "work",
        name: "Work Agent",
        workspace: "~/.openclaw/workspace-work",
        identity: { name: "WorkBot", emoji: "💼" },
      },
    ],
  },
}
```

## Subagents

Agents can spawn sub-agents for parallel tasks:

```json5
{
  agents: {
    defaults: {
      subagents: {
        model: "anthropic/claude-haiku-4-5",
        maxConcurrent: 8,
        archiveAfterMinutes: 30,
      },
    },
  },
}
```

Per-agent override:
```json5
{
  agents: {
    list: [{
      id: "main",
      subagents: { maxConcurrent: 4, model: "anthropic/claude-sonnet-4-5" },
    }],
  },
}
```

- Sub-agents inherit parent agent's workspace and tool policies
- `archiveAfterMinutes` — auto-archive idle sub-agent sessions
- Tool restriction: `tools.subagents` for sub-agent-specific tool policies
- **Nested subagents** (v2026.2.15+): Set `maxSpawnDepth` to allow sub-agents to spawn their own sub-agents (default: 1, max recommended: 3)
- **Deterministic spawn** (v2026.2.17+): `/subagents spawn` command for explicit subagent activation
- **Context overflow** (v2026.2.17+): Subagent context overflow managed via truncation/compaction to prevent crashes
- Subagent task messages are now prefixed with source context (v2026.2.17+ breaking change)

## Heartbeat

Periodic background agent runs:

```json5
{
  agents: {
    defaults: {
      heartbeat: {
        every: "1h",           // Interval
        model: "anthropic/claude-haiku-4-5",
        prompt: "Check for updates",
        target: { channel: "telegram", peer: "tg:123456789" },
      },
    },
    list: [{
      id: "main",
      heartbeat: { every: "2h", prompt: "Run scheduled tasks" },
    }],
  },
}
```

- Heartbeat runs as a silent agent turn
- Can target specific channel/peer for output delivery
- Per-agent override supported

## Routing Priority (Most-Specific-First)

1. Peer match (exact DM/group/channel ID)
2. Guild ID (Discord)
3. Team ID (Slack)
4. Account ID match for a channel
5. Channel-level match
6. Fallback to default agent

## Bindings

```json5
{
  bindings: [
    { agentId: "home", match: { channel: "whatsapp", accountId: "personal" } },
    { agentId: "work", match: { channel: "whatsapp", accountId: "biz" } },
    { agentId: "work", match: { channel: "telegram", peer: "-1001234567890" } },
    { agentId: "work", match: { channel: "discord", guildId: "guild-id" } },
    { agentId: "work", match: { channel: "slack", teamId: "team-id" } },
  ],
}
```

## Per-Agent Security Profiles

```json5
{
  agents: {
    list: [
      {
        id: "personal",
        sandbox: { mode: "off" },
        tools: { profile: "full" },
      },
      {
        id: "family",
        sandbox: { mode: "all", workspaceAccess: "ro" },
        tools: { profile: "minimal", deny: ["exec", "browser"] },
      },
      {
        id: "public",
        sandbox: {
          mode: "all",
          docker: { network: "none", memory: "512m" },
        },
        tools: {
          profile: "minimal",
          deny: ["exec", "browser", "web_fetch", "write_*"],
        },
      },
    ],
  },
}
```

## Session Scoping

```json5
{
  session: {
    scope: "per-sender",
    dmScope: "per-peer",               // per contact
    reset: { mode: "daily", atHour: 4 },
  },
}
```

`dmScope` options:
- `"main"` — all DMs share one session
- `"per-peer"` — separate per contact (default)
- `"per-channel-peer"` — separate per channel+contact
- `"per-account-channel-peer"` — full isolation

## Session Send Policy

Route outbound messages by channel and chat type:

```json5
{
  session: {
    sendPolicy: {
      whatsapp: { dm: "allow", group: "mention-only" },
      telegram: { dm: "allow", group: "allow" },
      discord: { dm: "allow", group: "mention-only" },
    },
  },
}
```

## Cross-Channel Identity

```json5
{
  session: {
    identityLinks: [
      { whatsapp: "+1(555)000-0123", telegram: "tg:000000001" },
    ],
  },
}
```

## Agent-to-Agent Communication

Enable inter-agent messaging:

```json5
{
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["work", "home"],  // Target agent IDs
    },
  },
  session: {
    agentToAgent: {
      maxPingPongTurns: 5,  // Prevent infinite loops
    },
  },
}
```

- Agents can send messages to other agents via the `agent_send` tool
- `maxPingPongTurns` limits back-and-forth to prevent runaway conversations
- Disabled by default: `tools.agentToAgent.enabled: false`

## Group Mention Patterns

```json5
{
  agents: {
    list: [
      {
        id: "coder",
        groupChat: { mentionPatterns: ["@coder", "hey coder"] },
      },
    ],
  },
}
```

## Multi-Account Channels

```json5
{
  channels: {
    whatsapp: {
      accounts: { personal: {}, biz: {} },
    },
  },
}
```

Login each account: `openclaw channels login`.

## Security Considerations

- **Never share auth profiles** across agents — prevents credential collision
- **Sandbox untrusted agents** — public/family agents always sandboxed
- **Restrict tool access** per agent based on trust level
- **Separate workspaces** — prevents data leakage between agents
- **Restrict sub-agent tools** — sub-agents should have same or more restrictive policies than parent
- **Limit spawn depth** — set `maxSpawnDepth` conservatively to prevent resource exhaustion from nested subagents
- **Heartbeat target validation** — ensure heartbeat target is an authorized peer
- **Agent-to-agent loop prevention** — always set `maxPingPongTurns` to prevent runaway
- **Disable agent-to-agent** unless needed: `tools.agentToAgent.enabled: false`
- **Review bindings** — ensure unknown traffic doesn't route to privileged agents
