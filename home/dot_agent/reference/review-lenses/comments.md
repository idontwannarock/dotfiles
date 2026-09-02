# Lens: comments

Does the prose still describe the code?

A wrong comment is worse than no comment: it is believed. This lens reads every
comment, docstring, and doc block the diff adds or touches, and checks it
against the code beside it.

## What to look for

**Untrue**
- Parameters, return types, and thrown errors that do not match the signature.
- Described behaviour that the body does not perform.
- Named types, functions, flags, files, or endpoints that do not exist, or that
  were renamed.
- Claimed complexity, performance, or thread-safety that the code does not
  deliver.
- Edge cases listed as handled that are not.
- Examples that would not run.

**Stale by construction**
- Comments describing a transitional state — "for now", "until X ships",
  "temporary" — with nothing that will prompt their removal.
- References to a ticket, branch, or migration that has since closed.
- TODO and FIXME for work already done.
- Line-by-line narration that must be re-edited every time the code moves.

**Missing where it counts**
- The *why*: a non-obvious choice, a workaround for someone else's bug, an
  ordering that matters, a constant with a derivation.
- Preconditions the caller must meet, and side effects it will not expect.
- The one paragraph an unfamiliar reader needs before a dense algorithm.

**Not earning its place**
- Restating the code in English.
- Section banners and decorative separators carrying no information.
- Commented-out code left as history — that is what git is for.

## How to report

Quote the comment, quote the code it contradicts, and give the corrected
wording. "This comment is unclear" is not actionable; a replacement sentence is.

Separate *wrong* from *absent*. A wrong comment is a defect. A missing one is a
suggestion, and only where the code is genuinely not self-evident.

Judge style against the file it lives in — language, voice, and comment density
should match the surrounding code, not an external house style.
