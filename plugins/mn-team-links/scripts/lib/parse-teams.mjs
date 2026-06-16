// Parse the `teamsRaw` map out of the MN Service "Config + Classification" node
// jsCode, and turn each entry into a Drive-folder link row.
//
// This is the SINGLE source of truth: the n8n node is the live config, we never
// store a copy of the team list here. We only READ it and project the folder IDs
// into Drive URLs. Every key/alias in `teamsRaw` is preserved as-is — nothing is
// merged, renamed, or dropped.

const DRIVE_FOLDER_BASE = 'https://drive.google.com/drive/folders/';

// A real Google Drive folder ID is long (≥19 chars, `[A-Za-z0-9_-]`) or a shared-
// drive root starting with `0A`. Anything shorter (e.g. a Slack-channel name that
// was mis-pasted into a folder field in n8n) is NOT turned into a fake URL — it is
// surfaced verbatim with an `(invalid?)` marker. This is presentation only; we do
// not alter the underlying n8n data.
export function looksLikeDriveId(id) {
  const s = String(id || '').trim();
  if (!s) return false;
  if (/^0A[A-Za-z0-9_-]+$/.test(s)) return true;
  return /^[A-Za-z0-9_-]{19,}$/.test(s);
}

export function driveUrl(id) {
  return looksLikeDriveId(id) ? DRIVE_FOLDER_BASE + String(id).trim() : '';
}

// Extract the `const teamsRaw = { ... };` object literal from the node jsCode and
// evaluate it. `promptTemplate` values reference `defaultPrompt` / `defaultPromptUA`
// (identifiers defined earlier in the node) — we stub those to '' so the literal
// evaluates standalone. No other identifiers appear inside teamsRaw values.
export function extractTeamsRaw(jsCode) {
  const code = String(jsCode || '');
  const anchor = code.indexOf('teamsRaw');
  if (anchor === -1) throw new Error('teamsRaw not found in node jsCode');

  const braceStart = code.indexOf('{', anchor);
  if (braceStart === -1) throw new Error('teamsRaw opening brace not found');

  // Balance braces, ignoring any that live inside string literals.
  let depth = 0;
  let i = braceStart;
  let quote = null; // active string delimiter: ' " or `
  for (; i < code.length; i++) {
    const ch = code[i];
    const prev = code[i - 1];
    if (quote) {
      if (ch === quote && prev !== '\\') quote = null;
      continue;
    }
    if (ch === "'" || ch === '"' || ch === '`') { quote = ch; continue; }
    if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) { i++; break; } }
  }
  if (depth !== 0) throw new Error('teamsRaw object literal is unbalanced');

  const objectLiteral = code.slice(braceStart, i);
  // eslint-disable-next-line no-new-func
  const factory = new Function(
    'defaultPrompt',
    'defaultPromptUA',
    `"use strict"; return (${objectLiteral});`
  );
  const teamsRaw = factory('', '');
  if (!teamsRaw || typeof teamsRaw !== 'object') {
    throw new Error('teamsRaw did not evaluate to an object');
  }
  return teamsRaw;
}

// Turn the raw map into link rows. Parent transcript folder = transcriptionFolderId
// (falls back to meetingNotesFolderId — in the live config they are the parent and
// are usually identical).
export function buildRows(teamsRaw) {
  return Object.entries(teamsRaw).map(([key, t]) => {
    const team = t || {};
    const parentId = String(team.transcriptionFolderId || team.meetingNotesFolderId || '').trim();
    const singleId = String(team.singleTranscriptsFolderId || '').trim();
    return {
      key,
      name: String(team.name || key || '').trim(),
      slackChannel: String(team.slackChannel || '').trim(),
      parentFolderId: parentId,
      parentFolderUrl: driveUrl(parentId),
      singleTranscriptsFolderId: singleId,
      singleTranscriptsUrl: driveUrl(singleId),
      // flags for presentation — the data is left untouched
      parentInvalid: !!parentId && !looksLikeDriveId(parentId),
      singleInvalid: !!singleId && !looksLikeDriveId(singleId),
    };
  });
}

// Match a query against key + name, case-insensitive substring. Empty query → all.
// Aliases (e.g. AUT / Automation / Aut all pointing at the same folder) are returned
// as separate rows — we never collapse them, the caller can dedupe by folder if wanted.
export function filterRows(rows, query) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return rows;
  return rows.filter(
    (r) => r.key.toLowerCase().includes(q) || r.name.toLowerCase().includes(q)
  );
}
