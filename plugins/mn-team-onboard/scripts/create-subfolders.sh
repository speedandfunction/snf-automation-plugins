#!/usr/bin/env bash
# Create the two team subfolders (Videos, Single Transcripts) under a Drive parent,
# acting as notes.bot, via the n8n helper webhook. Idempotent: re-running returns the
# same IDs instead of creating duplicates (the workflow does search-before-create).
#
# Usage:  scripts/create-subfolders.sh <parentFolderId>
# Env (load from .env):  MNB_SUBFOLDERS_WEBHOOK_URL, MNB_SUBFOLDERS_WEBHOOK_TOKEN
# Output: JSON { ok, parentId, videoFolderId, singleTranscriptsFolderId }
set -euo pipefail

# Load .env from the plugin root (or the repo root when run locally) if present, so the
# two webhook vars below are populated without the caller having to source it first.
# Re-sourcing after a manual `set -a; . .env` is harmless (idempotent).
_envfile="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/.env"
[ -f "$_envfile" ] && { set -a; . "$_envfile"; set +a; }

parent="${1:?parentId required (the Drive folder ID, not the URL)}"
: "${MNB_SUBFOLDERS_WEBHOOK_URL:?set MNB_SUBFOLDERS_WEBHOOK_URL (see .env)}"
: "${MNB_SUBFOLDERS_WEBHOOK_TOKEN:?set MNB_SUBFOLDERS_WEBHOOK_TOKEN (see .env)}"

curl -fsS -X POST "$MNB_SUBFOLDERS_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "x-mnb-token: ${MNB_SUBFOLDERS_WEBHOOK_TOKEN}" \
  -d "{\"parentId\":\"${parent}\"}"
