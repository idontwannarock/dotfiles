## 1. 建立 context/ bundle

- [x] 1.1 `git mv openspec/project.md context/overview.md`,讓 git 辨識為 rename(history 可追)
- [x] 1.2 從 `overview.md` 拆出 `glossary.md`(原「詞彙表」段)、`principles.md`(原「反覆適用的原則與約束」段),`overview.md` 只留原「這是什麼」段;各檔 `##` 標題升為 `#`
- [x] 1.3 新建 `context/capability-map.md`:原「方位:能力面在哪」段改寫為**分組與各組邊界**為主體,不逐一列舉 spec 名;補上原本漏列的 `project-context`;保留原段末關於 `## Purpose` 仍是 `TBD` 佔位的提醒
- [x] 1.4 為四個 concept 檔補 OKF frontmatter:`overview.md`/`glossary.md`/`capability-map.md` 為 `type: Reference`,`principles.md` 為 `type: Principle`;`description` 一律加雙引號
- [x] 1.5 新建 `context/index.md`:frontmatter 僅 `okf_version: "0.2"`,內容為範圍摘要 + 四檔路由;原檔頂部的三分法邊界 blockquote 收斂為此處的範圍摘要
- [x] 1.6 驗證內容無遺漏:以 `git show HEAD:openspec/project.md` 逐段對照,原 88 行每一段皆對應到新四檔之一(blocked by 1.2, 1.3)
- [x] 1.7 驗證 bundle 合規:四個 concept 檔的 frontmatter 通過 YAML parser、`type` 在既有三值內、僅 root `index.md` 帶 `okf_version`、所有相對連結可解析

## 2. 更新 inbound 引用

- [x] 2.1 更新 4 份 spec 的路徑指涉 —— **由 3.3／3.4 涵蓋**:實作時確認這 4 份的舊路徑全數落在被 MODIFIED/REMOVED 的 requirement 區塊內,無區塊外的殘留,分兩次編輯屬重複勞動
- [x] 2.2 更新 2 份 docs:`docs/claude-code.md`、`docs/codex-cli.md`
- [x] 2.3 更新 3 份 chezmoi shared body:`home/.chezmoitemplates/skills/{arch-review,grill,dev-workflow}.md`
- [x] 2.4 `README.md` 新增一行指向 `context/`
- [x] 2.5 驗證無殘留:`grep -rn 'openspec/project\.md'` 在非 `archive/` 路徑下無命中(blocked by 2.1-2.4)

## 3. spec 對齊

- [x] 3.1 套用 delta:新建 `openspec/specs/okf-bundle-conventions/spec.md` 與 `openspec/specs/project-context/spec.md`
- [x] 3.2 套用 delta:`openspec/specs/agent-reference-layout/spec.md` 移除兩條格式 requirement,新增 bundle 宣告 requirement
- [x] 3.3 套用 delta:`openspec/specs/{arch-review,discipline-skills,workflow-instructions}/spec.md` 的 MODIFIED requirement
- [x] 3.4 移除 `openspec/specs/project-context-doc/`(已由 `project-context` 取代)
- [x] 3.5 `openspec validate --all` 通過(blocked by 3.1-3.4)

## 4. 部署與驗證

- [x] 4.1 `chezmoi apply`(僅套用本 change 相關的 6 個目標,避免觸發三支待重跑的 `run_*` 腳本)後確認 `~/.claude/skills/{grill}/SKILL.md`、`~/.claude/commands/arch-review.md`、`~/.codex/skills/` 對應檔案已指向 `context/`,source 與實機一致
- [x] 4.2 驗證 `openspec/` 下已無 `project.md`,且 OpenSpec CLI 各命令(`openspec list`、`openspec status`、`openspec validate --all`)行為正常
