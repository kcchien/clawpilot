<div align="center">

<img src="assets/hero.jpg" alt="ClawPilot — Your OpenClaw Copilot" width="100%"/>

<br/>
<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent_Skill-Compatible-blueviolet?style=flat-square)](#-compatible-agents)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-v2026.2.9-e94560?style=flat-square)](https://openclaw.ai)
[![Platforms](https://img.shields.io/badge/Platforms-14_Chat_Apps-4ecca3?style=flat-square)](#-features)
[![Security](https://img.shields.io/badge/Security--First-OWASP_%7C_NIST_%7C_CVE-ff6b6b?style=flat-square)](#-bundled-security-scripts)

**A security-first agent skill that makes your AI assistant an OpenClaw expert.**<br/>
Install, configure, harden, and troubleshoot your self-hosted AI gateway — in natural language.

[Quick Install](#-quick-install) · [Compatible Agents](#-compatible-agents) · [Features](#-features) · [Security Scripts](#-bundled-security-scripts)

</div>

---

[OpenClaw](https://openclaw.ai) is a self-hosted gateway that connects chat apps (WhatsApp, Telegram, Discord, Slack, iMessage, Signal, LINE, and more) to AI agents. **ClawPilot** gives any compatible AI coding assistant deep knowledge of OpenClaw's architecture, configuration, security model, and deployment patterns.

## ⚡ Quick Install

```bash
npx skills add kcchien/clawpilot
```

That's it. Your AI agent will automatically load the skill when you ask about OpenClaw.

## 🤝 Compatible Agents

ClawPilot works with any AI coding assistant that supports the **Agent Skills** standard:

| Agent | Install Method |
|-------|---------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `npx skills add kcchien/clawpilot` |
| [OpenClaw Agents](https://openclaw.ai) | Copy to `~/.openclaw/skills/` |
| Other compatible agents | Any agent that reads `SKILL.md` as instructions |

> ClawPilot follows the open `SKILL.md` convention — a self-contained markdown file with metadata and instructions. Any AI agent that can discover and load `SKILL.md` files will work.

## 💬 What Can You Do With It?

Just talk to your AI assistant naturally:

- *"Set up OpenClaw with WhatsApp and Telegram"*
- *"Is my OpenClaw installation secure?"*
- *"Deploy OpenClaw to AWS with Docker"*
- *"My Discord bot stopped responding — help me debug"*
- *"Scan my session transcripts for leaked API keys"*
- *"Add a second agent with its own tools and sandbox"*
- *"Check if my version is affected by CVE-2026-25253"*

Your AI assistant will guide you step-by-step, always checking security before recommending changes.

## ✨ Features

- **Security-first approach** — Every config recommendation passes a security review (blast radius, credential exposure, network surface, prompt injection risk)
- **CVE awareness** — Automatically checks for known vulnerabilities (CVE-2026-25253, CVE-2026-24763, CVE-2026-25157)
- **14 chat platforms** — WhatsApp, Telegram, Discord, Slack, iMessage, Signal, LINE, Matrix, Teams, Google Chat, Mattermost, BlueBubbles, Feishu, Zalo
- **Multi-agent routing** — Agent isolation, per-agent sandbox/tools, session scoping, subagent management
- **Cloud deployment** — Docker, AWS, GCP, Fly.io, Railway, Render, Hetzner, and more
- **Secure remote access** — Tailscale Serve and SSH tunnel patterns (never raw `0.0.0.0`)
- **Skill supply chain security** — Detect malicious skills before installation

## 🔒 Bundled Security Scripts

Run these locally against your OpenClaw installation for deep inspection:

| Script | Purpose |
|--------|---------|
| `security_audit.sh` | Full audit — CVE detection, OWASP Agentic Top 10 mapping, NIST CSF alignment, supply chain scan |
| `config_inspector.sh` | Parse `openclaw.json` and report security-relevant settings with recommendations |
| `prompt_checker.sh` | Scan agent prompts (SOUL.md, AGENTS.md) for injection risks and missing guardrails |
| `session_scanner.sh` | Find leaked credentials (AWS keys, GitHub PATs, API keys) in session transcripts |

All scripts require only `bash` and standard Unix utilities — no extra dependencies.

## 📚 Reference Documentation

ClawPilot bundles comprehensive reference files that your AI agent reads on demand:

- **Configuration** — All config keys, environment variables, channel setup, session management
- **Security Hardening** — CVEs, OWASP mapping, NIST alignment, audit checklist, incident response
- **Cloud Deployment** — Docker, AWS, GCP, Fly.io, Tailscale, SSH, and more
- **Multi-Agent** — Routing rules, agent isolation, bindings, subagents, heartbeat

## 📋 Requirements

- An AI coding assistant that supports Agent Skills (e.g., [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenClaw](https://openclaw.ai) agents, or any `SKILL.md`-compatible agent)
- [OpenClaw](https://openclaw.ai) v2026.1.29+ (for full CVE patch coverage)
- `bash` (for running security scripts)

## 📄 License

[MIT](LICENSE)

---

<div align="center">

# 🐾 ClawPilot — OpenClaw 的 AI 副駕（AI Agent 通用）

[![授權: MIT](https://img.shields.io/badge/授權-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Agent Skill](https://img.shields.io/badge/Agent_Skill-通用相容-blueviolet?style=flat-square)](#-相容的-ai-agent)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-v2026.2.9-e94560?style=flat-square)](https://openclaw.ai)

**安全優先的 Agent 技能，讓你的 AI 助手成為 OpenClaw 專家**<br/>
用自然語言安裝、設定、強化與排除故障。

[快速安裝](#-快速安裝-1) · [相容 Agent](#-相容的-ai-agent) · [功能特色](#-功能特色) · [安全腳本](#-內建安全腳本)

</div>

---

[OpenClaw](https://openclaw.ai) 是一個自架式閘道器，將聊天應用程式（WhatsApp、Telegram、Discord、Slack、iMessage、Signal、LINE 等）連接到 AI 代理。**ClawPilot** 讓任何相容的 AI 編碼助手深入了解 OpenClaw 的架構、設定、安全模型和部署模式。

## ⚡ 快速安裝

```bash
npx skills add kcchien/clawpilot
```

就這樣。當你詢問 OpenClaw 相關問題時，AI Agent 會自動載入此技能。

## 🤝 相容的 AI Agent

ClawPilot 適用於任何支援 **Agent Skills** 標準的 AI 編碼助手：

| Agent | 安裝方式 |
|-------|---------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `npx skills add kcchien/clawpilot` |
| [OpenClaw Agents](https://openclaw.ai) | 複製到 `~/.openclaw/skills/` |
| 其他相容 Agent | 任何能讀取 `SKILL.md` 作為指令的 AI Agent |

> ClawPilot 遵循開放的 `SKILL.md` 慣例——一個包含 metadata 和指令的獨立 Markdown 檔案。任何能發現並載入 `SKILL.md` 的 AI Agent 都能使用。

## 💬 你可以問什麼？

用自然語言跟你的 AI 助手對話即可：

- *「幫我設定 OpenClaw 連接 WhatsApp 和 Telegram」*
- *「我的 OpenClaw 安裝安全嗎？」*
- *「用 Docker 部署 OpenClaw 到 AWS」*
- *「我的 Discord 機器人沒回應了，幫我查」*
- *「掃描我的 session 紀錄有沒有洩漏 API 金鑰」*
- *「新增第二個 agent，有自己的工具和沙箱」*
- *「檢查我的版本是否受 CVE-2026-25253 影響」*

你的 AI 助手會一步步引導你，並在建議修改前先檢查安全性。

## ✨ 功能特色

- **安全優先** — 每項設定建議都經過安全審查（爆炸半徑、憑證曝露、網路暴露面、Prompt Injection 風險）
- **CVE 感知** — 自動檢查已知漏洞（CVE-2026-25253、CVE-2026-24763、CVE-2026-25157）
- **14 個聊天平台** — WhatsApp、Telegram、Discord、Slack、iMessage、Signal、LINE、Matrix、Teams、Google Chat、Mattermost、BlueBubbles、飛書、Zalo
- **多代理路由** — Agent 隔離、獨立沙箱/工具、Session 範圍控制、子代理管理
- **雲端部署** — Docker、AWS、GCP、Fly.io、Railway、Render、Hetzner 等
- **安全遠端存取** — Tailscale Serve 和 SSH 隧道模式（絕不直接暴露 `0.0.0.0`）
- **技能供應鏈安全** — 安裝前偵測惡意技能

## 🔒 內建安全腳本

| 腳本 | 用途 |
|------|------|
| `security_audit.sh` | 完整稽核 — CVE 偵測、OWASP Agentic Top 10 對應、NIST CSF 對齊、供應鏈掃描 |
| `config_inspector.sh` | 解析 `openclaw.json`，報告安全相關設定與建議 |
| `prompt_checker.sh` | 掃描 Agent Prompt（SOUL.md、AGENTS.md）的注入風險與缺失防護 |
| `session_scanner.sh` | 在 Session 紀錄中找出洩漏的憑證（AWS 金鑰、GitHub PAT、API 金鑰） |

所有腳本只需 `bash` 和標準 Unix 工具，無需額外依賴。

## 📋 前置條件

- 支援 Agent Skills 的 AI 編碼助手（例如 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)、[OpenClaw](https://openclaw.ai) Agents，或任何相容 `SKILL.md` 的 Agent）
- [OpenClaw](https://openclaw.ai) v2026.1.29+（完整 CVE 修補覆蓋）
- `bash`（執行安全腳本用）

## 📄 授權

[MIT](LICENSE)
