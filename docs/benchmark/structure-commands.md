# Structure-command device test (Milestone B)

The manual pass that decides whether voice structure commands are trustworthy on real speech. It is
**not** a recognition-rate benchmark. The question it answers is:

> Did As Told ever treat ordinary words as a command?

A missed command is tolerable. A phantom one is not (`../../RULES.md` §2 — when uncertain, preserve the
spoken words).

## What is already proven without a device

The full corpus below runs as text through the real parser in
`Tests/YourlyTests/VoiceCommandCorpusTests.swift` — commands, the ten conversational false positives, and
the Telugu/English code-switch cases. All pass. So everything downstream of the transcript is pinned, and
this device test exists to answer the one thing a unit test cannot:

**does the transcription model produce the text the parser was tested against?**

Watch especially for what the model does with command punctuation (`new paragraph`, `new paragraph...`,
`new paragraph…`, `Okay, new paragraph`) and with the leading filler of natural speech ("so yeah um…").

## How to run it

Speak each line naturally — do not enunciate for the machine. For each recording note the transcript that
landed and whether structure was applied.

### Clear commands (structure expected)

1. "New paragraph. I want to write something else."
2. "New paragraph... I want to write something else."
3. "New paragraph… I want to write something else."
4. "Heading. Alaska trip."
5. "Subheading. Where to stay."
6. "Bullet list. Anchorage. Next item. Seward. Next item. Denali."
7. "Checklist. Call Ravi. Next item. Buy groceries."
8. "End list. Another thing I was thinking about…"

### Conversational speech (words expected, no structure)

9. "The phrase new paragraph is annoying."
10. "I told him to add a checklist."
11. "The heading was completely wrong."
12. "Maybe use a bullet list for that."
13. "She said new paragraph and then continued."
14. "Okay, new paragraph."
15. "I don't know, maybe heading back tomorrow makes sense."
16. "My checklist is getting too long."
17. "So yeah um new paragraph... actually I don't know maybe let's talk about something else."
18. "Okay new paragraph, I think Alaska might be better."

### Code-switch (English commands inside natural mixed speech)

19. "నాకు ఇంకో idea ఉంది. New paragraph. Maybe మనం Seward లో two nights ఉండచ్చు."
20. "ఇక్కడ checklist add చేయాలి." — must stay literal; the speaker never issued a standalone command.

## Pass criteria

**Must-have — any failure blocks the milestone:**

- [ ] zero false-positive structural actions across 9–18 and 20
- [ ] no words disappear
- [ ] no punctuation left behind after a recognized command
- [ ] Telugu/Hindi text intact, script preserved
- [ ] structure lands at the correct insertion point
- [ ] appending by voice from the reading state still works
- [ ] caret insertion while editing still works

**Nice-to-have:** high recognition across 1–8. A command that stays as text is acceptable; ordinary speech
that restructures the document is not.

## Recording results

Log the transcript for each line. If a false positive appears, add the transcript verbatim to
`VoiceCommandCorpusTests.swift` as a failing case *before* changing the parser — that is the corpus the
parser is held to.
