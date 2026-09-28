# App catalog

| id | Name | Bundle ID | Team | Web URL | Kind | Parent |
|---|---|---|---|---|---|---|
| claude | Claude | com.anthropic.claudefordesktop | Q6L2SF6YDW | https://claude.ai | app | — |
| claude-code | Claude Code | (CLI) | — | https://claude.ai/code | cli: `claude` | claude |
| chatgpt | ChatGPT | com.openai.chat, com.openai.codex | 2DC432GLL2 | https://chatgpt.com | app | — |
| codex | Codex | (CLI) | — | https://chatgpt.com/codex | cli: `codex` | chatgpt |
| gemini | Gemini | (none) | — | https://gemini.google.com | web | — |
| grok | Grok | (none) | — | https://grok.com | web | — |
| copilot | Copilot | com.microsoft.copilot-mac | UBF8T346G9 | https://copilot.microsoft.com | app | — |
| perplexity | Perplexity | ai.perplexity.mac | (unverified) ⚠ | https://www.perplexity.ai | app | — |
| cursor | Cursor | com.todesktop.230313mzl4w4u92 | VDXQ22DGB9 ⚠ | https://cursor.com | app | — |

## Notes
- Apps marked ⚠ still require Developer ID or Mac App Store signatures even without team pinning.
- Source of truth: Pip/Registry/catalog.json.
- Claude Code: opens Terminal.app, shows a folder picker first (recent folders at the top), then runs `claude` in that folder. The folder path is passed as a separate argument and never interpolated into a shell string (see security-reviewer).
