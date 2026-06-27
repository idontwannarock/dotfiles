## 1. Baseline capture (regression guard)

- [x] 1.1 Render `home/.chezmoiexternal.toml` with chezmoi and save the output as the "before" baseline (e.g. `chezmoi execute-template < home/.chezmoiexternal.toml > before.txt`)

## 2. Annotate Tier A pins

- [x] 2.1 Add `# renovate: datasource=… depName=…` comments above each Tier A pin per the design table (rtk, starship, zellij, uv, jq, ripgrep, kubelogin, yt-dlp, hugo, nexttrace, golangci-lint, gopass, docker-compose, nvm, 7zip, cascadia NF, jetbrains-mono, go)
- [x] 2.2 Add `versioning=` / `extractVersion=` where needed (jq `extractVersion`, yt-dlp `versioning=loose`, 7zip `versioning=loose`, go `datasource=golang-version`)
- [x] 2.3 Confirm shared-variable entries (kubelogin ×2) are annotated once on the variable line

## 3. Annotate Tier B pins

- [x] 3.1 kubectl → `github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.+)$`
- [x] 3.2 maven → `datasource=maven depName=org.apache.maven:maven-core`
- [x] 3.3 docker CLI → `github-releases depName=docker/cli extractVersion=^v(?<version>.+)$`

## 4. Refactor + annotate the JDKs

- [x] 4.1 Convert each of the 5 Temurin entries from a hardcoded full URL to a `$jdkNNVersion` variable, templating both encodings (`+`→`%2B` in the tag, `+`→`_` in the asset)
- [x] 4.2 Annotate each with `github-releases depName=adoptium/temurinNN-binaries` + the `jdk-` extractVersion (major-locking is automatic — separate repos per major)
- [x] 4.3 Verify each refactored entry renders the EXACT current URL (diff against the baseline URL string)

## 5. Defer the messy tools

- [x] 5.1 Add `# renovate: ignore — deferred to mirror phase (<reason>)` comments for jdtls, ffmpeg, dos2unix, and vim (do not add bump annotations)

## 6. Create renovate.json

- [ ] 6.1 Write root `renovate.json`: `extends` base config, custom regex manager with `managerFilePatterns` for `home/.chezmoiexternal.toml` and the matchString capturing the `# renovate:` comment + the `{{- $…Version := "…" }}` line
- [ ] 6.2 Set PR hygiene: `dependencyDashboard: true`, weekly `schedule`, labels, no `automerge`, `ignoreUnstable`

## 7. Verify

- [ ] 7.1 Render the annotated file again and diff against the "before" baseline — non-JDK lines byte-identical; JDK lines render the same URLs
- [ ] 7.2 Run `npx --yes renovate-config-validator` and confirm valid
- [ ] 7.3 Dry-run Renovate (or inspect the would-be dependency dashboard) and reconcile the detected-dependency count against the Tier A + Tier B + JDK set; fix any missed/mis-captured pin
- [ ] 7.4 Confirm no deferred tool (jdtls/ffmpeg/dos2unix/vim) and neither `statusline`/`passgen` appears in the detected set

## 8. Enablement (one-time, user action)

- [ ] 8.1 Enable the hosted Renovate GitHub App on the repo and merge the onboarding PR (user-driven; document the steps)
- [ ] 8.2 Note in repo docs how to add a future tool (two-line `# renovate:` comment) and that jdtls/ffmpeg/dos2unix/vim are intentionally deferred to the mirror phase
