// Template for ONE entry to add to `teamsRaw` in the n8n Code node
// "Config + Classification" (MN Service). Match the existing formatting exactly:
// 2-space indent, single quotes, trailing comma on every field.
//
// CRITICAL: the OBJECT KEY (e.g. 'AUT:MNB') is what routes meetings — it is matched
// case-sensitively, character-for-character, against the [Tag] in the calendar event
// title. The `name` field is metadata only and is NEVER used for routing.

'<TEAM_TAG>': {
  name: '<TEAM_TAG>',                  // metadata only; convention = equal to the key
  promptTemplate: '',                  // '' => default English prompt; defaultPromptUA for Ukrainian teams
  meetingNotesFolderId: '<PARENT_ID>', // the team's parent folder ID
  transcriptionFolderId: '<PARENT_ID>',// typically identical to meetingNotesFolderId
  videoFolderId: '<VIDEO_FOLDER_ID>',  // Videos subfolder ID (from the helper webhook)
  meetingNotesDocId: '',               // leave '' for a new team; helper finds the active doc by tag
  transcriptDocId: '',                 // leave '' for a new team
  slackChannel: '<SLACK_CHANNEL_OR_EMPTY>', // channel name without '#'; '' => optional/no team channel
  singleTranscriptsFolderId: '<SINGLE_TRANSCRIPTS_FOLDER_ID>', // from the helper webhook
},
