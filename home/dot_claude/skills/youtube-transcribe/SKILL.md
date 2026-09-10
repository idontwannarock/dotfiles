---
name: youtube-transcribe
description: >
  Use when the user wants to know what a YouTube video says, or wants one archived as
  text — pasting a YouTube URL with no other instruction, asking 「這支影片在講什麼」、
  「幫我抓逐字稿」、「把這個影片存起來」、「總結一下這個影片」, or "what does this video
  say", "get me the transcript", "summarise this video". Archives the video, audio,
  transcript, thumbnail and metadata to disk, then has a subagent write the summary to a
  file so the main context never holds the transcript. Skip for videos the user has
  already transcribed, and for audio files already on disk that need no download.
---

# YouTube video to transcript and summary

## Overview

Three stages. Only the third one costs model context.

| Stage | Who does it | Context cost |
|---|---|---|
| Download video, audio, thumbnail, metadata | `yt-transcribe` (shell) | none |
| Produce the transcript | `yt-transcribe` (shell) | none |
| Summarise the transcript | a subagent, writing to a file | the subagent's, not yours |

You dispatch and report. You do **not** read the transcript yourself unless the user asks
you to discuss its content in depth.

## Stage 1 and 2: run the script

```
yt-transcribe <url>
```

Useful options: `--base-dir DIR` (default `~/.agent/media`), `--no-video` when the user
only wants the words, `--lang CODE` and `--model NAME` to override language detection and
the whisper model. `yt-transcribe --help` lists the rest.
`docs/user-scripts.md` in the dotfiles repo carries the design decisions and the traps.

The script prints a manifest. Read `out_dir`, `transcript`, `est_tokens`,
`recommended_tier` and `summary_target` from it. Everything else you need is on disk.

A run takes seconds when the uploader wrote subtitles, and a few minutes when speech-to-text
has to run. Say which happened; `transcript_source` in the manifest tells you.

**If the script fails, stop and report the error.** Do not hand a broken pipeline to a
subagent, and do not substitute your own download commands. The failures worth naming:
a stale `yt-dlp`, a missing JS runtime, and `HTTP 429` on the subtitle endpoint.

## Stage 3: dispatch the summary

Pick the agent from `recommended_tier`. The thresholds are the script's, not yours:

| `recommended_tier` | Dispatch |
|---|---|
| `haiku` | `Agent` with `model: haiku` |
| `sonnet` | `Agent` with `model: sonnet` |
| `cross-model` | A counterpart agent first; fall back to `model: opus` when none is available |

For `cross-model`, read `~/.agent/reference/cross-model-counterparts.md` for the readiness
probe and launch arguments of each agent kind. That file is written for code review, where
the counterpart runs in a herdr pane against a repo. Summarising one file needs none of
that: a non-interactive `codex exec` run pointed at `out_dir` is enough. Take the probe and
the authentication facts from that reference; ignore the pane choreography.

Override the tier when the user asks for depth, or when the summary will feed a decision
rather than a reading list. State that you overrode it and why.

The subagent directive must be self-contained: absolute paths to `metadata.md` and the
transcript, the exact frontmatter block below, the body structure you want, and the
instruction to reply with only the path, the line count and the timestamp it used.

## The summary file

The subagent writes `summary.md` next to the transcript, starting with this frontmatter.
Every value comes from the manifest or from `metadata.md`; none of it is guessed.

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

Those seven `source_*` and `transcript_*` fields exist so a reader months later can answer
"which video, which transcript, which model, when" without opening anything else. A summary
missing them is not reusable, so treat the block as mandatory.

Body structure, in the user's language:

1. `# <title>`, then `## 核心主張` — the one claim the video is built on.
2. `## 重點` — the argument, with every number, named example and case study the speaker
   cites. Those are the most valuable part and the easiest for a small model to drop. Say so
   in the directive.
3. `## 值得追問的地方` — 2 to 4 specific weaknesses.
4. `## 原文金句` — at most 3 short quotes in the original language, one line of gloss each.

Instruct the subagent to paraphrase and to keep quoting inside that limit.

## Reporting back

Give the user the summary's substance and the path to the folder. Do not paste the
transcript. Name the transcript source and the model that summarised, because both change
how much they should trust the result.

## Revisit this skill once the knowledge system exists

**Status as of 2026-09-10: there is no knowledge system on this machine yet.** The artifacts
land in `~/.agent/media/`, which has no version control and no cross-machine sync — the same
terms as `~/.agent/local/`. A rebuilt machine loses them.

That directory is a holding area chosen because nothing better existed, **not** a decision
that video artifacts belong outside a knowledge base. When the user builds one, reopen these
four questions rather than porting the current shape across:

- **Where artifacts live.** `--base-dir` exists so the answer can move. The per-video folder
  name (`<upload date>-<video id>`) may not suit a system with its own identifier scheme.
- **Whether `summary.md` is still the right output.** A knowledge system may want notes
  linked into a graph, not one standalone file per video. The frontmatter is designed to
  survive that move; the file layout is not.
- **Whether the media files stay next to the notes.** A 6-minute video is about 110 MB at
  full quality. That is fine in a scratch directory and questionable inside anything synced
  or version-controlled.
- **Whether this skill should still own the summary step.** If the knowledge system has its
  own ingestion and summarisation, this skill should shrink to the download and transcript
  stages and hand off.

Do not quietly redesign around a knowledge system that does not exist yet. Wait until it does,
then review this section with the user.
