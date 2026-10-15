# Keep an online video on disk

## What this does

`media-fetch` saves one video from any site `yt-dlp` supports: YouTube, Facebook reels,
and the rest. It writes one folder with the video, the thumbnail, hand-written subtitles
when the uploader wrote any, and the full metadata. It does not transcribe and does not
summarise.

A bare video URL means "keep this". Run the script, report where it went, and stop. Do not
offer a summary unless the user asks what the video says; that is the `video-summary`
skill, which calls this one first.

## Run it

```
media-fetch <url>
```

Useful options: `--base-dir DIR` (default `~/.agent/media`), and `--no-video` to keep only
the audio as `audio.mp3`. `media-fetch --help` lists them. The dotfiles repo's
`docs/user-scripts.md` carries the design decisions and the traps.

The script prints a manifest. `out_dir` is the folder. `video`, `audio`, `subtitles` and
`thumbnail` name each file, or say `(none)`.

Running it again on the same URL is safe. `yt-dlp` skips a video file that already exists,
so a second run takes seconds and downloads nothing again.

**If the script fails, stop and report the error.** Do not substitute your own download
commands. The failures worth naming: a stale `yt-dlp`, a missing JS runtime, and `HTTP 429`
on the YouTube subtitle endpoint. A private or friends-only video needs the user's login,
which this script does not have.

## Reporting back

Give the user `out_dir` and the video title from `metadata.md`. One or two lines. Mention
that `media-transcribe <out_dir>` makes a transcript later without a second download.
