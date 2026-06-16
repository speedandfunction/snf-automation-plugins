// Trimmed excerpt of the real MN Service "Config + Classification" node jsCode,
// kept as a parser fixture. Mirrors the shapes the parser must survive:
//  - promptTemplate referencing identifiers (defaultPrompt / defaultPromptUA)
//  - aliases pointing at the same folder (AUT / Automation / Aut)
//  - empty singleTranscriptsFolderId
//  - a special-character key ("Nick's Test") with a non-Drive-ID single value
//  - a shared-drive root id starting with 0A (AWESOME)
//  - a colon/ampersand key (S&F:CI), a "| Int" alias pair
const defaultPrompt = 'You are an AI meeting assistant {{ $json.body.meeting_type }} ...';
const defaultPromptUA = 'Ви — AI-асистент {{ $json.body.meeting_type }} ...';

const teamsRaw = {
  'AUT:MNB': {
    name: 'AUT:MNB',
    promptTemplate: '',
    meetingNotesFolderId: '1ZN4AElF0JKJpw_wP6zctymKwUR06O6S4',
    transcriptionFolderId: '1ZN4AElF0JKJpw_wP6zctymKwUR06O6S4',
    videoFolderId: '19YZn7FcTBzMYX1sJ2lL0R6dXmxMtNEJz',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: '',
    singleTranscriptsFolderId: '1Nur2RnHU6cqxg9ZVgJeHCPvHYykZxNBV',
  },
  'Automation': {
    name: 'Automation',
    promptTemplate: defaultPrompt,
    meetingNotesFolderId: '1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx',
    transcriptionFolderId: '1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx',
    videoFolderId: '1tERk7xOvBPWoeJdIfQlYF2ujqEnbfWiP',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: 'automation-internal',
    singleTranscriptsFolderId: '',
  },
  'AUT': {
    name: 'AUT',
    promptTemplate: defaultPrompt,
    meetingNotesFolderId: '1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx',
    transcriptionFolderId: '1Rzb1nVmvlKf_enEkWB2q6tcixDgiC0sx',
    videoFolderId: '1tERk7xOvBPWoeJdIfQlYF2ujqEnbfWiP',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: 'automation-internal',
    singleTranscriptsFolderId: '',
  },
  "Nick's Test": {
    name: "Nick's Test",
    promptTemplate: '',
    meetingNotesFolderId: '1F_9Ac272V8V4h0QkPGzDtR8Z8IGYM6vj',
    transcriptionFolderId: '1F_9Ac272V8V4h0QkPGzDtR8Z8IGYM6vj',
    videoFolderId: '1-4-Ob0SLnu2ibQ_Z6gNoemhZR2cfifSV',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: '',
    singleTranscriptsFolderId: 'sashko-private',
  },
  'AWESOME': {
    name: 'AWESOME',
    promptTemplate: '',
    meetingNotesFolderId: '0AGz9qu5CVQ0mUk9PVA',
    transcriptionFolderId: '0AGz9qu5CVQ0mUk9PVA',
    videoFolderId: '1HQkCf38MMD-_Mpj8LiUl_NV5FLWPzYK4',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: 'awesome-bdd-and-mcp',
    singleTranscriptsFolderId: '14I2yIWsoZ5BTJD-Sqk9nVkU23iC11eYJ',
  },
  'Two Labs: DPT Support | Int': {
    name: 'Two Labs: DPT Support',
    promptTemplate: '',
    meetingNotesFolderId: '1_KUBWL7FGp2eOClp10Mqqv4kwBLfRDy7',
    transcriptionFolderId: '1lLPeL4GKv5DKfU9w3IgC0avqXYXV7dIs',
    videoFolderId: '1r_BOz8y2xGI7A233H_oJNNl-O5lUfOzw',
    meetingNotesDocId: '',
    transcriptDocId: '',
    slackChannel: 'twolabs-support_int',
    singleTranscriptsFolderId: '1hRvxMSu1dZaZQmyOSgUkl6suRnqlHmKU',
  },
};

return [{ json: { teams: teamsRaw } }];
