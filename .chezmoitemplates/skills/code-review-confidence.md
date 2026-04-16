## Confidence Scoring

After all review tasks complete, score each reported issue independently using a lightweight model (e.g. haiku). Each scoring task receives the original diff + the issue description, and returns a confidence score.

**Rubric** (provide verbatim to scoring tasks):

| Score | Meaning |
|-------|---------|
| 0 | False positive — doesn't hold up to scrutiny, or pre-existing issue |
| 25 | Might be real, but could be false positive. Stylistic issues not explicitly required by project guidelines. |
| 50 | Verified real issue, but nitpick or unlikely in practice. Not important relative to the rest of the changes. |
| 75 | Verified real issue that will likely be hit in practice. The current approach is insufficient. Directly impacts functionality. |
| 100 | Confirmed real issue that will happen frequently. Evidence directly confirms this. |

**False positive examples** (provide to scoring tasks):
- Pre-existing issues not introduced by the diff
- Something that looks like a bug but isn't
- Pedantic nitpicks a senior engineer wouldn't flag
- Issues a linter, typechecker, or compiler would catch (assume CI runs separately)
- General quality concerns (test coverage, documentation) unless explicitly required by project guidelines
- Intentional functionality changes directly related to the broader change
- Real issues on lines the author did not modify

**Threshold**: Filter out issues scoring below **80**. If no issues meet the threshold, report that no significant issues were found.

**Output grouping**:
- Issues ≥ 80: Show in the main report under Critical / Suggestions
- Issues 50-79: Collapse into a "Minor / Nitpicks" section (titles only, no details)
- Issues < 50: Omit entirely
