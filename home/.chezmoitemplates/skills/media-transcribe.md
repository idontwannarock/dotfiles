# Turn a saved video into a transcript

## What this does

`media-transcribe` makes the transcript for a folder that `media-fetch` wrote. It reads
only what is on disk and never downloads. It does not summarise: that is the
`video-summary` skill, which calls this one after `media-fetch`.

| Step | Who does it | Context cost |
|---|---|---|
| Produce the transcript | `media-transcribe` (shell) | none |
| Fix speech-to-text mistakes (English whisper transcripts only) | two agents and `media-transcript-review` | two short tables |

Do **not** read the transcript yourself unless the user asks you to discuss its content in
depth. The point of the file is that the words stay on disk.

## Step 1: transcribe

```
media-transcribe <out_dir>
```

Useful options: `--lang CODE` and `--model NAME` override language detection and the
speech-to-text model; `--no-subs` ignores saved subtitles. `media-transcribe --help`
lists them.

The script prints a manifest. Read `out_dir`, `transcript`, `transcript_source`,
`est_tokens`, `recommended_tier` and `summary_target` from it. Everything else you need is
on disk.

A run takes seconds when the uploader wrote subtitles, and a few minutes when
speech-to-text has to run. Say which happened; `transcript_source` in the manifest tells
you.

**If the script fails, stop and report the error.** Do not substitute your own download
commands. The failures worth naming: a stale `yt-dlp`, a missing JS runtime, and `HTTP 429`
on the subtitle endpoint.

## Step 2: fix speech-to-text mistakes

Run this only when `transcript_source` starts with `whisper:` and the language is English.
Skip it for saved subtitles (a person wrote them) and for any other language (not tested).

Whisper mistakes are mostly names and look-alike words: "pros" for "prose", "Graphbot" for
"Grokbot". Context alone settles most of them, and a video frame settles more: a slide
often spells the word. No person confirms anything here. The step fixes what it is sure
of, and lists the rest.

Dispatch both agents with the **Agent tool**. **Read `~/.agent/reference/summariser-tiers.md`**
to turn a tier into an agent. Each directive must be self-contained, because the agent
inherits nothing: give absolute paths. Each agent replies with its table as text, and you
write the file. Claude Code rejects some subagent writes with "Subagents should return
findings as text, not write report files.", and which dispatch gets rejected is not
predictable.

1. **List the suspects.** Dispatch an agent of the `small` tier. Directive: read
   `transcript.txt` and `metadata.md` (absolute paths); list misheard or misspelled words,
   look-alike words that do not fit the sentence, the same name spelled two ways, and
   **every** person, company, product and tool name; skip spoken-style grammar; one row per
   occurrence; reply with one table, columns `line | written text | suggested fix`, and
   nothing else. Create `<out_dir>/review/` and write the reply to `review/suspects.txt`.
2. **Collect the evidence.** `media-transcript-review prep <out_dir> <out_dir>/review/suspects.txt`
   writes `review/cases.md`: each suspect with the lines around it and, when `video.*` is
   on disk, one frame from that moment. It tolerates a line number that is off by two.
3. **Judge.** Dispatch an agent of the `medium` tier, whatever the transcript size: the job
   is to read images and weigh evidence, not to read a lot of text. Directive: read
   `review/cases.md`; open every frame; a slide may hold no useful text; spell a name the
   way the slide does; give `-` as the fix when the phrase is right; the written text may
   widen to a neighbouring word (`a lean` to `Lean`) but must stay exact text from the line;
   `high` only when the context or a frame settles it, `medium` when it rests on world
   knowledge, `low` for a guess; reply with one table, columns
   `line | written text | corrected text | confidence | evidence`. Write the reply to
   `review/verdicts.txt`.
4. **Apply.** `media-transcript-review apply <out_dir> <out_dir>/review/verdicts.txt`.
   It fixes the `high` rows in all five transcript files, copies the originals to
   `whisper-raw/` the first time, and writes `transcript-review.md` with what it changed
   and what it left in doubt.

Report the two counts the script prints (applied, doubts) and name `transcript-review.md`.

This step improves the transcript; it does not gate anything. If an agent or the script
fails, say so and hand the transcript on as it is. The manifest from Step 1 stays valid:
`est_tokens` and `recommended_tier` were measured before the fix, and the fix changes
them by a few tokens at most.

## Reporting back

Give the user `out_dir`, the transcript path, `transcript_source`, and the Step 2 counts
when it ran. Say it was skipped when it did not run, and why. Do not paste the transcript.
