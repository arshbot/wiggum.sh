#!/bin/bash

# Ralph Loop Setup Script
# Creates state file for in-session Ralph loop

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
PROMPT_FILE=""

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Ralph Loop - Interactive self-referential development loop

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --prompt-file <path>             Read prompt from a file instead of inline
  --max-iterations <n>             Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'    Promise phrase (USE QUOTES for multi-word)
  -h, --help                       Show this help message

DESCRIPTION:
  Starts a Ralph Wiggum loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use --prompt-file for large, detailed prompts stored in a file. The file
  contents become the loop prompt — useful for multi-page task specifications.

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --prompt-file PROMPT.md --max-iterations 50
  /ralph-loop --prompt-file ./tasks/refactor.md --completion-promise 'COMPLETE'
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/ralph-loop.local.md

  # View full state:
  head -10 .claude/ralph-loop.local.md
HELP_EOF
      exit 0
      ;;
    --prompt-file)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --prompt-file requires a file path argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --prompt-file PROMPT.md" >&2
        echo "     --prompt-file ./tasks/build-api.md" >&2
        echo "     --prompt-file ~/prompts/refactor.txt" >&2
        echo "" >&2
        echo "   You provided: --prompt-file (with no path)" >&2
        exit 1
      fi
      PROMPT_FILE="$2"
      shift 2
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   You provided: --max-iterations (with no number)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   Invalid: decimals (10.5), negative numbers (-5), text" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --completion-promise 'DONE'" >&2
        echo "     --completion-promise 'TASK COMPLETE'" >&2
        echo "     --completion-promise 'All tests passing'" >&2
        echo "" >&2
        echo "   You provided: --completion-promise (with no text)" >&2
        echo "" >&2
        echo "   Note: Multi-word promises must be quoted!" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      # Non-option argument - collect all as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Resolve prompt: --prompt-file takes precedence, then inline args
if [[ -n "$PROMPT_FILE" ]]; then
  # Expand ~ if present
  PROMPT_FILE="${PROMPT_FILE/#\~/$HOME}"

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "❌ Error: Prompt file not found: $PROMPT_FILE" >&2
    echo "" >&2
    echo "   Make sure the file exists and the path is correct." >&2
    echo "   Relative paths are resolved from the current working directory." >&2
    exit 1
  fi

  PROMPT=$(cat "$PROMPT_FILE")

  if [[ -z "$PROMPT" ]]; then
    echo "❌ Error: Prompt file is empty: $PROMPT_FILE" >&2
    exit 1
  fi

  # Warn if inline args were also provided
  if [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
    echo "⚠️  Warning: --prompt-file overrides inline prompt arguments" >&2
    echo "   Using contents of: $PROMPT_FILE" >&2
    echo "" >&2
  fi
else
  # Join all prompt parts with spaces
  PROMPT="${PROMPT_PARTS[*]}"
fi

# Validate prompt is non-empty
if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "" >&2
  echo "   Ralph needs a task description to work on." >&2
  echo "" >&2
  echo "   Examples:" >&2
  echo "     /ralph-loop Build a REST API for todos" >&2
  echo "     /ralph-loop --prompt-file PROMPT.md --max-iterations 20" >&2
  echo "     /ralph-loop Fix the auth bug --max-iterations 20" >&2
  echo "" >&2
  echo "   For all options: /ralph-loop --help" >&2
  exit 1
fi

# Create state file for stop hook (markdown with YAML frontmatter)
mkdir -p .claude

# Quote completion promise for YAML if it contains special chars or is not null
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/ralph-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
PROMPT_SOURCE="inline"
if [[ -n "$PROMPT_FILE" ]]; then
  PROMPT_SOURCE="$PROMPT_FILE"
fi

cat <<EOF
🔄 Ralph loop activated in this session!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/} (ONLY output when TRUE - do not lie!)"; else echo "none (runs forever)"; fi)
Prompt source: $PROMPT_SOURCE

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: head -10 .claude/ralph-loop.local.md

⚠️  WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

🔄
EOF

# Output the initial prompt
echo ""
echo "$PROMPT"

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "CRITICAL - Ralph Loop Completion Promise"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "To complete this loop, output this EXACT text:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo ""
  echo "STRICT REQUIREMENTS (DO NOT VIOLATE):"
  echo "  ✓ Use <promise> XML tags EXACTLY as shown above"
  echo "  ✓ The statement MUST be completely and unequivocally TRUE"
  echo "  ✓ Do NOT output false statements to exit the loop"
  echo "  ✓ Do NOT lie even if you think you should exit"
  echo ""
  echo "IMPORTANT - Do not circumvent the loop:"
  echo "  Even if you believe you're stuck, the task is impossible,"
  echo "  or you've been running too long - you MUST NOT output a"
  echo "  false promise statement. The loop is designed to continue"
  echo "  until the promise is GENUINELY TRUE. Trust the process."
  echo ""
  echo "  If the loop should stop, the promise statement will become"
  echo "  true naturally. Do not force it by lying."
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "HANDOFF BRIEF — Required on final iteration"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "  Before outputting the completion promise, include a"
  echo "  hyper-condensed handoff: 3-6 bullets pointing the human"
  echo "  to where they can dig in and verify. NOT a changelog."
  echo ""
  echo "  Example:"
  echo "    ## Handoff"
  echo "    - Run \`npm start\`, open localhost:3000, click through checkout"
  echo "    - Known edge cases documented in BUGS.md"
  echo "    - \`npm test\` — all green, 2 integration tests are slow"
  echo "    - Went with SQLite over Postgres, rationale in README"
  echo "═══════════════════════════════════════════════════════════"
fi
