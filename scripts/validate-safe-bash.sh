#!/bin/bash
# scripts/validate-safe-bash.sh
#
# PreToolUse backstop for the `implementer` subagent. Blocks common
# destructive / production-affecting Bash command patterns before they
# execute. This is a safety net, not the primary control — the agent's
# own instructions are the primary control, this catches what slips
# through. Extend the pattern list as your project's actual risk surface
# becomes clearer; this is deliberately not exhaustive.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Destructive filesystem operations
if echo "$COMMAND" | grep -iE '\brm\s+-rf\s+(/|~|\$HOME|\.\.)' > /dev/null; then
  echo "Blocked: recursive force-delete on a root/home/parent path. Confirm scope with a human first." >&2
  exit 2
fi

# Force-pushing to protected branches
if echo "$COMMAND" | grep -iE '\bgit\s+push\s+.*--force.*\b(main|master|prod|production)\b' > /dev/null; then
  echo "Blocked: force-push to a protected branch requires human approval." >&2
  exit 2
fi

# Destructive SQL without a WHERE-scoped equivalent
if echo "$COMMAND" | grep -iE '\b(DROP|TRUNCATE)\b' > /dev/null; then
  echo "Blocked: destructive SQL (DROP/TRUNCATE) requires human approval." >&2
  exit 2
fi

# Infra destroy operations
if echo "$COMMAND" | grep -iE '\bterraform\s+destroy\b|\bpulumi\s+destroy\b' > /dev/null; then
  echo "Blocked: infrastructure destroy command requires human approval." >&2
  exit 2
fi

# Cluster/resource deletion
if echo "$COMMAND" | grep -iE '\bkubectl\s+delete\b' > /dev/null; then
  echo "Blocked: kubectl delete requires human approval." >&2
  exit 2
fi

# Cloud CLI delete/destroy against live resources
if echo "$COMMAND" | grep -iE '\b(az|aws|gcloud)\b.*\b(delete|destroy|terminate)\b' > /dev/null; then
  echo "Blocked: cloud resource deletion/termination requires human approval." >&2
  exit 2
fi

# Common production deploy entrypoints (adjust to your actual scripts)
if echo "$COMMAND" | grep -iE '\bdeploy[:_-]?(prod|production)\b|\bnpm\s+run\s+deploy:prod\b' > /dev/null; then
  echo "Blocked: production deploy command requires human approval." >&2
  exit 2
fi

exit 0
