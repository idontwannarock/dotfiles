# Online video to transcript and summary

## Overview

Three stages. Only the third one costs model context.

| Stage | Who does it | Context cost |
|---|---|---|
| Download video, thumbnail, subtitles, metadata | the `media-fetch` skill | none |
| Produce the transcript | `media-transcribe` (shell) | none |
| Summarise the transcript | the summariser for the tier; the result goes to a file | see below |

The URL can come from any site `yt-dlp` supports, not only YouTube. Facebook reels work.

This skill is for a question about what a video says. A bare URL with no question means
"keep it": that is the `media-fetch` skill alone, and this skill does not run.

Do **not** read the transcript yourself unless the user asks you to discuss its content in
depth. The point of the file is that the words stay on disk.

## Stage 1: fetch

Follow the `media-fetch` skill and take `out_dir` from its manifest. Run it even when the
video may already be on disk: it skips files that exist, so a second run costs seconds and
downloads nothing again. Pass `--no-video` when the user only wants the words.

## Stage 2: transcribe

```
media-transcribe <out_dir>
```

Useful options: `--lang CODE` and `--model NAME` override language detection and the
speech-to-text model; `--no-subs` ignores saved subtitles. `media-transcribe --help`
lists them.

The script prints a manifest. Read `out_dir`, `transcript`, `est_tokens`,
`recommended_tier` and `summary_target` from it. Everything else you need is on disk.

A run takes seconds when the uploader wrote subtitles, and a few minutes when
speech-to-text has to run. Say which happened; `transcript_source` in the manifest tells
you.

**If the script fails, stop and report the error.** Do not hand a broken pipeline to a
summariser, and do not substitute your own download commands. The failures worth naming:
a stale `yt-dlp`, a missing JS runtime, and `HTTP 429` on the subtitle endpoint.

## Stage 3: summarise

`recommended_tier` is `small`, `medium` or `large`. The script measures bytes and names a
size; it names no model, because a byte counter has no reason to know one.

**Read `~/.agent/reference/summariser-tiers.md` to turn the tier into an agent.** That
file holds the thresholds, the per-kind dispatch table, and how to record the model id. It
is a table rather than a branch here because which agent does the work is decided at
runtime, long after this file renders.

Override the tier when the user asks for depth, or when the summary will feed a decision
rather than a reading list. State that you overrode it and why.

{{/* axis: reader — which dispatch tool exists, and whether naming a model is allowed on it, is a property of the tool executing this file, not of the text being summarised */ -}}
{{ if eq .n.tool "claude" -}}
Dispatch with the **Agent tool**, using the model the tier table names. The directive must
be self-contained, because the agent inherits nothing: absolute paths to `metadata.md` and
the transcript, the exact frontmatter block below, the body structure, and the instruction
to reply with the whole `summary.md` content inside one markdown fence and nothing else.

The agent returns the file; you write it. Claude Code rejects some subagent writes with
"Subagents should return findings as text, not write report files.", and which dispatch
gets rejected is not predictable: on 2026-10-16, 6 of 9 summary agents were rejected.

Write the fence content to `summary.md`, then report the path, the line count and
`summarized_at`. The summary passes through your context; the transcript never does.
{{- else -}}
Dispatch with **`spawn_agent`**. Leave the `model` field unset: a spawned agent inherits
your model, and the tier table's Claude column does not port across. The tier tells you how
much care the pass needs, not which model to name.

Pass `fork_turns: "none"` — the default forks your whole conversation into the agent. The
directive must therefore be self-contained: absolute
paths to `metadata.md` and the transcript, the exact frontmatter block below, the body
structure, and the instruction to reply with only the path it wrote, the line count, and
the timestamp it used.

Report that reply. The transcript never enters your context.

For a `large` transcript, give the agent named passes and have it write each one down
before opening the next.
{{- end }}

## The summary file

`summary.md` goes next to the transcript, starting with this frontmatter. Every value
comes from the manifest or from `metadata.md`; none of it is guessed.

```
---
type: VideoSummary
source_video_id: "<id>"
source_url: "<url>"
source_title: <title, JSON-quoted>
source_channel: <channel, JSON-quoted>
source_upload_date: "<YYYY-MM-DD>"
source_duration: "<h:mm:ss>"
transcript_file: "transcript.txt"
transcript_source: "<manifest transcript_source>"
transcript_est_tokens: <manifest est_tokens>
summarized_by: "<the model id that wrote this>"
summarized_at: "<date -Iseconds>"
---
```

`summarized_by` records the model id that actually ran, never the tier name. The tier is a
routing decision; the id is the fact.

Those `source_*` and `transcript_*` fields exist so a reader months later can answer "which
video, which transcript, which model, when" without opening anything else. A summary
missing them is not reusable, so treat the block as mandatory.

Body structure, in the user's language:

1. `# <title>`, then `## 核心主張` — the one claim the video is built on.
2. `## 重點` — the argument, with every number, named example and case study the speaker
   cites. Those are the most valuable part and the first thing a summary drops. Say so in
   the directive.
3. `## 值得追問的地方` — 2 to 4 specific weaknesses.
4. `## 原文金句` — at most 3 short quotes in the original language, one line of gloss each.

Paraphrase, and keep quoting inside that limit.

## Reporting back

Give the user the summary's substance and the path to the folder. Do not paste the
transcript. Name the transcript source and the model that summarised, because both change
how much they should trust the result.

## Revisit this skill once the knowledge system exists

**Status as of 2026-09-10: there is no knowledge system on this machine yet.** The
artifacts land in `~/.agent/media/`, which has no version control and no cross-machine
sync. A rebuilt machine loses them.

That directory is a holding area chosen because nothing better existed, **not** a decision
that video artifacts belong outside a knowledge base. When the user builds one, reopen
these four questions rather than porting the current shape across:

- **Where artifacts live.** `--base-dir` exists so the answer can move. The per-video
  folder name (`<upload date>-<video id>`) may not suit a system with its own identifiers.
- **Whether `summary.md` is still the right output.** A knowledge system may want notes
  linked into a graph, not one standalone file per video. The frontmatter is designed to
  survive that move; the file layout is not.
- **Whether the media files stay next to the notes.** A 6-minute video is about 110 MB at
  full quality. That is fine in a scratch directory and questionable inside anything
  synced or version-controlled.
- **Whether this skill should still own the summary step.** If the knowledge system has
  its own ingestion and summarisation, this skill shrinks to the download and transcript
  stages and hands off.

Do not quietly redesign around a knowledge system that does not exist yet. Wait until it
does, then review this section with the user.
