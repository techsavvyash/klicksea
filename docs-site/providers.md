# Providers

## Codex

Install the official [Codex CLI](https://github.com/openai/codex), then run:

```sh
codex login
```

Choose Codex in Settings. KlickSea invokes the CLI using its existing login, ephemeral execution, a read-only sandbox, no shell tools, and captured JPEGs. It does not copy authentication tokens. Account eligibility, plan limits, and provider policies apply.

## Claude

Install [Claude Code](https://code.claude.com/docs/en/overview). Choose Claude in Settings and save an Anthropic API key. KlickSea stores it in macOS Keychain and uses Claude Code's bare, tool-free, multimodal execution mode.

**API usage is billed separately.** KlickSea currently does not offer Claude subscription/OAuth reuse. Anthropic's Agent SDK guidance requires approval for third-party products offering that login. See [the official SDK documentation](https://code.claude.com/docs/en/agent-sdk/overview).

## Paths and models

Leave paths and model fields empty for automatic discovery/default models. Discovery checks `~/.local/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. If detection fails, set the full CLI path. Use an up-to-date CLI supporting the flags documented in the source.
