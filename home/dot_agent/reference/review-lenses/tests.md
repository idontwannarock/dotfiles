# Lens: tests

If this change broke, would a test go red?

Not "is coverage high". Coverage counts lines executed; this lens asks whether
a *behaviour* is pinned down. A line can be covered by a test that would pass
no matter what the line did.

## What to look for

**Gaps that matter**
- A branch the diff introduces that no test enters.
- Error paths: the code handles a failure, and nothing proves the handling works.
- Boundaries the `correctness` lens cares about — empty, first, last, maximum —
  asserted nowhere.
- Negative cases: validation that rejects, permissions that deny, input that
  should be refused.
- Behaviour that only appears under concurrency, retry, or timeout.

**Tests that will not hold**
- Asserting on internals — private fields, call counts, the exact shape of an
  intermediate value — so a refactor that preserves behaviour turns them red.
- Asserting so loosely that a real regression stays green: `assertNotNull`,
  `toBeTruthy`, comparing a value to itself, a snapshot nobody reads.
- Mocks so deep that the test exercises the mock rather than the code.
- Shared mutable fixtures that make the suite order-dependent.

**What not to ask for**
- Tests for trivial accessors that contain no logic.
- A test that restates the implementation line by line.
- Coverage of a path already exercised by an existing integration test — look
  before asking.

## How to report

For each gap, state the concrete regression it would catch: *"delete the
`retries > 0` check and every test still passes"*. A suggestion you cannot
attach a failure to is not worth the maintenance it will cost.

Read the repo's own testing conventions before recommending a shape — check
`CLAUDE.md` / `AGENTS.md` and the existing suite for the framework, naming, and
level (unit, integration) already in use.
