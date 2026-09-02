{{ template "skills/code-review-context.md" . }}
{{ template "skills/code-review-scope.md" . }}
## Lenses

| Lens | File | The question |
|------|------|--------------|
| security | `security.md` | Can someone make this do something it should not? |
| failure-handling | `failure-handling.md` | When something goes wrong, does anyone find out? |

Both, because the two failure modes compound. A swallowed error is how a failed
authorisation check becomes an allowed request, and how an attack in progress
leaves no trace to find it by.

{{ template "skills/code-review-dispatch.md" . }}
{{ template "skills/code-review-confidence.md" . }}
Two adjustments for this flow. Reachability is the first question, before
severity: a weakness no untrusted input can reach is not a vulnerability, and
belongs in the report as an observation rather than a finding. And a finding
that survives the filter is not downgraded for being unlikely — likelihood is
the attacker's choice, not yours.

## Output

---

**Security Review**

**Scope**: [reviewed what]
**Diff size**: [N files changed, +X/-Y lines]

**Risk Level**: [🔴 High / 🟡 Medium / 🟢 Low]

🔴 **Vulnerabilities**
- [what an attacker does] — _boundary: [where untrusted input enters]. Consequence: [...]. Fix: [...]_

🟡 **Error Handling Issues**
- [swallowed failure / unjustified fallback / message that hides the cause] — _consequence: [...]_

🔍 **Observations** (not reachable, worth knowing)
- [weakness, and why nothing untrusted can reach it today]

🟢 **Secure Practices**
- [positive observation]

---

## Guardrails

- **Do not modify code** — this is a read-only review
- **Full diff** — every reviewer must receive the full diff
- **No exploits** — describe the class, the entry point, and the fix; never a working exploit
- **Reachability first** — order findings by what untrusted input can reach, then by impact
