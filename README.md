# wiggum.sh

Ralph Wiggum technique for Claude Code — iterative AI development loops.

## Install

```bash
curl -fsSL wiggum.sh | bash
```

Restart Claude Code after installing.

## Usage

```bash
# Inline prompt
/ralph-loop Build a REST API --completion-promise 'DONE' --max-iterations 50

# Prompt from file (for large goals)
/ralph-loop --prompt-file PROMPT.md --completion-promise 'COMPLETE' --max-iterations 100

# Cancel a running loop
/cancel-ralph
```

### Options

| Flag | Description |
|------|-------------|
| `--prompt-file <path>` | Read prompt from a file instead of inline |
| `--max-iterations <n>` | Stop after N iterations (default: unlimited) |
| `--completion-promise <text>` | Phrase that signals completion |

### Prompt files

Write your prompt in a markdown file for complex, multi-page goals:

```bash
/ralph-loop --prompt-file ./tasks/build-api.md --max-iterations 50
```

The file contents become the loop prompt. Each iteration receives the same prompt and sees its previous work in the filesystem.

## How it works

1. `/ralph-loop` creates a state file at `.claude/ralph-loop.local.md`
2. A stop hook intercepts Claude's exit attempts
3. The hook re-feeds the same prompt, incrementing the iteration counter
4. Claude sees its previous work in modified files and git history
5. Loop exits when the completion promise is detected or max iterations reached

## Uninstall

```bash
rm -rf ~/.claude/plugins/cache/claude-code-plugins/ralph-wiggum
```

## Credits

Based on [Geoffrey Huntley's Ralph technique](https://ghuntley.com/ralph/).
