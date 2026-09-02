# Lens: correctness

Does this code do the wrong thing?

Only defects in behaviour belong here. Structure that is ugly but correct
belongs to `design.md`; a rule the repo wrote down belongs to
`conventions.md`; what happens *after* something already went wrong belongs
to `failure-handling.md`.

## What to look for

**Logic**
- Conditions inverted, off-by-one, wrong operator, wrong variable.
- Branches that can never be reached, or that fall through when they should not.
- State mutated in an order the rest of the code does not expect.

**Absent values**
- A value read without establishing it exists — null, nil, `None`, undefined,
  an empty collection, a missing key, a zero-row result.
- A default substituted for a missing value where the default is a valid
  value, so the two become indistinguishable downstream.

**Boundaries**
- First and last element, empty input, single element, maximum size.
- Integer overflow, precision loss, truncation on cast.
- Encoding, line endings, and path separators where the code crosses a
  platform boundary.

**Concurrency and time**
- Shared state written from more than one thread, task, or process without
  a guard.
- Check-then-act pairs that are not atomic.
- Ordering assumed between operations that have none.
- Timeouts, retries, and clocks: what happens when the clock jumps backwards.

**Resources**
- Handles, connections, locks, and file descriptors that are opened on a path
  that can return early.
- Unbounded growth — caches with no eviction, queues with no limit.

## How to report

Every finding must name the input or state that triggers it, and what the code
does instead of the right thing. A finding you cannot make concrete that way is
a guess; drop it.

Do not report an issue the compiler, type checker, or linter would catch. CI
runs separately.
