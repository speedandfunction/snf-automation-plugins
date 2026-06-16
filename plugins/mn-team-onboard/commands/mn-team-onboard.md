---
argument-hint: "<teamTag> <parentFolderUrl> [slackChannel] (e.g. 'AUT:MNB https://drive.google.com/drive/folders/... automation')"
description: "Onboard a new team to the MN Service (Meeting Notes) pipeline: create Drive subfolders + add one teamsRaw routing entry (Stage then Prod), self-validated with rollback."
---

Invoke the `mn-team-onboard:mn-team-onboard` skill via the Skill tool, passing `$ARGUMENTS` verbatim. The skill requires a team tag and a parent Drive folder link (Slack channel optional); if either is missing it stops and asks. It is a WRITER skill — it edits the n8n `teamsRaw` config and creates Drive subfolders via the token-protected webhook.
