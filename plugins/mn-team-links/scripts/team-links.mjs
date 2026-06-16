#!/usr/bin/env node
// team-links — resolve an MN Service team to its Google Drive transcript folder link.
//
// It turns the live `teamsRaw` map from the MN Service "Config + Classification" node
// into a compact Team → Drive-folder table. Primary input is the node's jsCode piped
// in by the assistant (which already has n8n connected via MCP) — so NO API key is
// stored anywhere. A direct REST fetch is available only as an optional headless
// fallback (set N8N_API_KEY for automation/cron use).
//
// Input precedence:
//   1. --jscode-file <path>   read the node jsCode from a file
//   2. --stdin / piped stdin  read the node jsCode from stdin   ← MCP path
//   3. N8N_API_KEY in env     fetch the workflow over REST       ← optional fallback
//
// Usage (MCP path — the assistant pipes the node code in):
//   node scripts/team-links.mjs "AUT:MNB" < config-node.js
//   n8n_get_workflow(...) → save node jsCode → pipe it here
//
// Usage (filters / output):
//   node scripts/team-links.mjs                 # all teams
//   node scripts/team-links.mjs "two labs"      # filter by tag or name (substring)
//   node scripts/team-links.mjs --json AUT      # machine-readable JSON

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { extractTeamsRaw, buildRows, filterRows } from './lib/parse-teams.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  try {
    const text = readFileSync(join(__dirname, '..', '.env'), 'utf8');
    for (const line of text.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && process.env[m[1]] === undefined) {
        process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
      }
    }
  } catch { /* no .env — fine, MCP path needs none */ }
}

function readStdin() {
  try {
    return readFileSync(0, 'utf8'); // fd 0 = stdin
  } catch {
    return '';
  }
}

// Optional REST fallback — only reached if no jsCode was piped/given AND a key exists.
async function fetchConfigNodeCodeViaRest() {
  const apiUrl = (process.env.N8N_API_URL || '').replace(/\/$/, '');
  const apiKey = process.env.N8N_API_KEY || '';
  const workflowId = process.env.MN_WORKFLOW_ID || 'SkEnOMQyotDXM05Z';
  const nodeName = process.env.MN_CONFIG_NODE || 'Config + Classification';
  const res = await fetch(`${apiUrl}/workflows/${workflowId}`, {
    headers: { 'X-N8N-API-KEY': apiKey, accept: 'application/json' },
  });
  if (!res.ok) throw new Error(`n8n API ${res.status} ${res.statusText} for workflow ${workflowId}`);
  const wf = await res.json();
  const node = (wf.nodes || []).find((n) => n.name === nodeName);
  if (!node) throw new Error(`Node "${nodeName}" not found in workflow ${workflowId}`);
  const jsCode = node.parameters && node.parameters.jsCode;
  if (!jsCode) throw new Error(`Node "${nodeName}" has no jsCode`);
  return jsCode;
}

async function resolveJsCode(opts) {
  if (opts.jscodeFile) return readFileSync(opts.jscodeFile, 'utf8');
  if (opts.stdin || !process.stdin.isTTY) {
    const piped = readStdin();
    if (piped.trim()) return piped;
  }
  if (process.env.N8N_API_KEY) return fetchConfigNodeCodeViaRest();
  throw new Error(
    'No input. Pipe the "Config + Classification" node jsCode in (MCP path):\n' +
    '  node scripts/team-links.mjs "<query>" < config-node.js\n' +
    'or set N8N_API_KEY in .env for the optional REST fallback.'
  );
}

function renderTable(rows) {
  if (!rows.length) return 'No matching team.';
  const cell = (r) => {
    const parent = r.parentFolderUrl
      || (r.parentInvalid ? `(invalid id: ${r.parentFolderId})` : '—');
    const single = r.singleTranscriptsUrl
      || (r.singleInvalid ? `(invalid id: ${r.singleTranscriptsFolderId})` : '—');
    const slack = r.slackChannel ? `#${r.slackChannel}` : '—';
    return `| ${r.key} | ${parent} | ${single} | ${slack} |`;
  };
  return [
    '| Team (tag) | Parent transcript folder | Single transcripts | Slack |',
    '|---|---|---|---|',
    ...rows.map(cell),
  ].join('\n');
}

async function main() {
  loadEnv();
  const argv = process.argv.slice(2);
  const opts = { json: false, stdin: false, jscodeFile: null };
  const words = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--json') opts.json = true;
    else if (a === '--stdin') opts.stdin = true;
    else if (a === '--jscode-file') opts.jscodeFile = argv[++i];
    else words.push(a);
  }
  const query = words.join(' ').trim();

  const jsCode = await resolveJsCode(opts);
  const teamsRaw = extractTeamsRaw(jsCode);
  const rows = filterRows(buildRows(teamsRaw), query);

  if (opts.json) {
    process.stdout.write(JSON.stringify(rows, null, 2) + '\n');
    return;
  }
  if (query && rows.length === 1 && rows[0].parentFolderUrl) {
    process.stdout.write(`${rows[0].key} → ${rows[0].parentFolderUrl}\n\n`);
  }
  process.stdout.write(renderTable(rows) + `\n\n${rows.length} team(s).\n`);
}

main().catch((err) => {
  process.stderr.write(`team-links: ${err.message}\n`);
  process.exit(1);
});
