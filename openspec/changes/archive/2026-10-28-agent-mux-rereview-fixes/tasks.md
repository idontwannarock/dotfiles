## 1. Fixes

- [x] 1.1 Separate `queryfail` from `unknown`; the Ghostex wait skips only `queryfail`
- [x] 1.2 herdr state file without `pane=`
- [x] 1.3 `ghostex_project` returns its error; the caller reports it once

## 2. Verification

- [x] 2.1 One test per fix that goes red when the fix is reverted
- [x] 2.2 Shell tests under sh and bash; `openspec validate --all --strict`
