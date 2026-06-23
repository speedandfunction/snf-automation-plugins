#!/usr/bin/env node
// gen-readme.mjs — regenerate the AUTOGEN regions of the top-level README.md from the
// manifests (single source of truth). Deterministic, no network, no LLM.
//
//   node scripts/gen-readme.mjs          # rewrite README.md in place
//   node scripts/gen-readme.mjs --check   # exit 1 if README.md is out of date (for CI)
//
// Source of truth:
//   .claude-plugin/marketplace.json      → marketplace name + ordered plugins[] (name, description, source, homepage)
//   plugins/<name>/.claude-plugin/plugin.json → per-plugin `command` + `requirements` (presentation metadata)
// To add a plugin: add it to marketplace.json (+ its plugin.json) and re-run this script — the README
// table and install list regenerate. CI (.github/workflows/readme.yml) runs it on every push.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const README = join(ROOT, 'README.md');
const readJSON = (p) => JSON.parse(readFileSync(p, 'utf8'));

const market = readJSON(join(ROOT, '.claude-plugin', 'marketplace.json'));
const marketName = market.name;

const firstSentence = (s) => {
  const m = String(s).match(/^.*?[.](?=\s|$)/s); // up to the first period followed by space/end
  return (m ? m[0] : String(s)).trim();
};
const cell = (s) => String(s ?? '—').replace(/\|/g, '\\|').replace(/\n+/g, ' ').trim();

const plugins = (market.plugins || []).map((p) => {
  let meta = {};
  try { meta = readJSON(join(ROOT, p.source, '.claude-plugin', 'plugin.json')); } catch { /* presentation fields optional */ }
  return {
    name: p.name,
    // Never fall back to a local filesystem path (ROOT) in a public README.
    homepage: p.homepage || meta.homepage || '#',
    desc: firstSentence(p.description || meta.description || ''),
    command: meta.command || '—',
    requirements: meta.requirements || '—',
  };
});

// --- region 1: install list ---
const installBlock = [
  '```text',
  ...plugins.map((p) => `/plugin install ${p.name}@${marketName}`),
  '```',
].join('\n');

// --- region 2: plugins table ---
const tableBlock = [
  '| Plugin | Command | What it does | Requirements |',
  '|---|---|---|---|',
  ...plugins.map(
    (p) => `| **[${p.name}](${p.homepage})** | ${cell(p.command)} | ${cell(p.desc)} | ${cell(p.requirements)} |`,
  ),
].join('\n');

const regions = { install: installBlock, plugins: tableBlock };

let readme = readFileSync(README, 'utf8');
const original = readme;
for (const [key, body] of Object.entries(regions)) {
  // Anchor the markers to WHOLE LINES (m flag) so a cell value that happens to contain the
  // literal "<!-- END:AUTOGEN … -->" mid-line can never satisfy the match and truncate the region.
  const re = new RegExp(`(^<!-- BEGIN:AUTOGEN ${key} -->$)[\\s\\S]*?(^<!-- END:AUTOGEN ${key} -->$)`, 'm');
  if (!re.test(readme)) {
    console.error(`gen-readme: missing AUTOGEN region "${key}" in README.md (markers must each be on their own line: <!-- BEGIN:AUTOGEN ${key} --> … <!-- END:AUTOGEN ${key} -->)`);
    process.exit(2);
  }
  // Defense-in-depth: a generated body must never contain a whole-line closing marker.
  if (body.split('\n').some((l) => l.trim() === `<!-- END:AUTOGEN ${key} -->`)) {
    console.error(`gen-readme: generated "${key}" body contains the closing marker on its own line — aborting to avoid corruption.`);
    process.exit(2);
  }
  readme = readme.replace(re, `$1\n${body}\n$2`);
}

const check = process.argv.includes('--check');
if (readme === original) {
  console.log('gen-readme: README.md is up to date.');
  process.exit(0);
}
if (check) {
  console.error('gen-readme: README.md is OUT OF DATE — run `node scripts/gen-readme.mjs` and commit.');
  process.exit(1);
}
writeFileSync(README, readme);
console.log(`gen-readme: README.md regenerated (${plugins.length} plugins).`);
