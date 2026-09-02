# Lens: failure-handling

When something goes wrong, does anyone find out?

The bug itself belongs to `correctness.md`. This lens starts one step later:
an error has already happened, and the question is whether the code surfaces
it, hides it, or quietly substitutes something else.

## What to look for

**Swallowed errors**
- Empty catch or rescue blocks.
- Catch blocks that log at debug level and continue as if nothing happened.
- Errors converted to a return of null, empty, zero, or `false` with nothing
  recorded — the caller cannot distinguish failure from a legitimate result.
- `?.`, `try?`, `|| default`, and similar constructs used to skip past an
  operation that was supposed to happen.

**Catch breadth**
- A handler that catches a base exception type when it means to catch one
  specific failure. List the unrelated errors it will now absorb — a typo in a
  field name, an out-of-memory, a cancellation — and say what each will look
  like to the user once absorbed.

**Fallbacks**
- Falling back to a second code path, a cached value, a default, or a stub.
- For each: was the fallback asked for, or is it covering a failure the caller
  should have been told about? A fallback nobody requested is a silent failure
  with extra steps.
- Mock, fake, or stub implementations reachable outside test code.

**Propagation**
- Errors caught at a layer that cannot do anything about them.
- Errors caught before cleanup that the cleanup then never runs.
- Retries that exhaust their attempts and return as though the last one worked.

**The message**
- Does it say what failed, and what the reader can do next?
- Does it carry enough context to identify the specific operation and inputs?
- Would it let someone debug this six months from now without the code open?

## How to report

For each finding, state the failure that gets hidden and who is left confused —
the end user, the operator reading logs, or the next person to debug it.

Judge logging and error-reporting against **this repo's** conventions: read
`CLAUDE.md` / `AGENTS.md` and look at how neighbouring code reports errors.
Do not assume a logging library, an error-tracking service, or an error-id
registry that this repo does not use.
