# Lens: security

Can someone make this do something it should not?

Read the diff as an attacker who can control every input that crosses a trust
boundary — request bodies, query parameters, headers, file contents, file
names, environment variables, command-line arguments, and anything read back
from a database another user can write to.

## What to look for

**Injection**
- Data concatenated into an interpreter: SQL, a shell command, HTML, a
  template, a path, a URL, LDAP, a regular expression, a serialisation format.
- The fix is nearly always parameterisation or an argument vector — escaping by
  hand is a finding in itself.
- Path traversal: user input reaching a filesystem path without normalisation
  and a containment check.

**Authentication and authorisation**
- A new route, handler, command, or exported function reachable without a check
  its neighbours perform.
- Authorisation decided from a value the caller supplied — an id in the body, a
  role in a token that is never verified.
- Checks performed once at the edge while the inner call is also reachable.
- Comparison of secrets with a non-constant-time equality.

**Secrets and exposure**
- Credentials, tokens, keys, or connection strings in source, config, test
  fixtures, or committed example files.
- Secrets reaching a log, an error message, a URL, a stack trace, or a crash
  report.
- Error responses that reveal internals — paths, versions, queries, stack
  traces — to an untrusted caller.
- Personal data widened without the handling the repo already applies to it.

**Crypto and randomness**
- A general-purpose PRNG where an unpredictable value is needed — tokens,
  identifiers, salts, nonces.
- Hand-rolled cryptography, ECB mode, a reused IV or nonce, a hard-coded key.
- Passwords stored with a fast hash rather than a password hash.
- Certificate or hostname verification disabled.

**Untrusted deserialisation and dependencies**
- Deserialising attacker-controlled bytes into arbitrary types.
- A new dependency, a registry change, or a pinned version that moved — and
  whether an install or build script now runs code from it.

## How to report

State the boundary, the input, and the reachable consequence. A finding on a
value that cannot cross a trust boundary is not a vulnerability; say so and
drop it.

Rank by reachability first, then impact. A theoretical weakness behind an
authenticated admin-only path outranks nothing.

Do not include a working exploit. Describe the class, the entry point, and the
fix.
