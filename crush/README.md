# Local Crush config notes

## Removed model limits

Removed these custom values from `crush.json` on 2026-08-12 so gateway metadata remains authoritative:

| Models | `context_window` | `default_max_tokens` |
|---|---:|---:|
| `claude-opus-5`, `claude-opus-4-8`, `claude-fable-5` | 1,000,000 | 32,000 |
| `claude-opus-4-1-20250805` | 200,000 | 32,000 |
| `claude-sonnet-4-20250514` | 200,000 | 16,000 |
| `claude-3-5-haiku-20241022` | 200,000 | 8,192 |
| `claude-opus-4-8:api`, `claude-sonnet-5:api`, `claude-sonnet-4-6:api`, `claude-fable-5:api` | 1,000,000 | 32,000 |
| `claude-haiku-4-5:api` | 200,000 | 16,000 |
| `gpt-5.6-luna:api` | 400,000 | 32,000 |
| `gpt-5.6-sol:api` | 1,050,000 | 128,000 |
| `zai/glm-5.2` | 200,000 | 32,000 |

`claude-opus-5` had the same values in both the personal Anthropic and agent-gateway providers.
