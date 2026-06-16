#!/usr/bin/env node
// Offline test for the parser — runs without n8n access. It feeds the fixture node
// jsCode through the same extraction the CLI uses and asserts the link projection.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { extractTeamsRaw, buildRows, filterRows } from './lib/parse-teams.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const code = readFileSync(join(__dirname, 'fixtures', 'sample-node.js'), 'utf8');

let failures = 0;
const ok = (cond, msg) => { if (!cond) { failures++; console.error('FAIL:', msg); } else console.log('ok  -', msg); };

const teamsRaw = extractTeamsRaw(code);
const rows = buildRows(teamsRaw);
const by = (k) => rows.find((r) => r.key === k);

ok(rows.length === 6, `parsed all 6 entries (got ${rows.length})`);
ok(by('AUT:MNB').parentFolderUrl === 'https://drive.google.com/drive/folders/1ZN4AElF0JKJpw_wP6zctymKwUR06O6S4', 'AUT:MNB parent folder URL');
ok(by('AUT:MNB').singleTranscriptsUrl.endsWith('1Nur2RnHU6cqxg9ZVgJeHCPvHYykZxNBV'), 'AUT:MNB single transcripts URL');
ok(by('Automation').singleTranscriptsUrl === '' && !by('Automation').singleInvalid, 'empty single → no URL, not flagged invalid');
ok(by('Automation').parentFolderUrl === by('AUT').parentFolderUrl, 'aliases AUT/Automation kept separate but share folder');
ok(by("Nick's Test").singleInvalid === true && by("Nick's Test").singleTranscriptsUrl === '', "non-Drive single ('sashko-private') flagged invalid, no fake URL");
ok(by('AWESOME').parentFolderUrl.endsWith('0AGz9qu5CVQ0mUk9PVA'), 'shared-drive root (0A...) accepted as folder id');
ok(filterRows(rows, 'two labs').length === 1, 'substring filter by name "two labs"');
ok(filterRows(rows, 'aut').length === 3, 'case-insensitive filter "aut" matches AUT:MNB + Automation + AUT');

console.log(failures ? `\n${failures} failing assertion(s)` : '\nAll assertions passed.');
process.exit(failures ? 1 : 0);
