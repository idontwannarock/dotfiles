## 1. `docs/renovate.md` 開頭與內文對齊

- [x] 1.1 改寫 L5-7:auto-merge 已存在,`nothing auto-merges` 不再成立。新敘述要與 L84-87 的 auto-merge 章節一致(patch/minor/pin 由 CI gate 自動合併、`major` 人審、`minimumReleaseAge` 3 天),並保留唯一仍成立的那句保證:`chezmoi apply` 前不會改到任何機器
- [x] 1.2 全檔複讀,確認沒有其他段落殘留 auto-merge 之前的假設

## 2. `docs/superpowers/` 歸檔

- [x] 2.1 `git mv` 四份文件到三個 change 目錄,依實際性質改名(見 design.md D4 對照表);不建 `.openspec.yaml`,不補 proposal 與 delta
- [x] 2.2 新建 `openspec/changes/archive/README.md`:說明這三個目錄是 pre-OpenSpec 記錄、只帶當時真的存在的 artifact、內部連結可能失效。只寫這一份(blocked by 2.1)
- [x] 2.3 修 `docs/corp-ssh-setup.md:8` 與 `docs/corp-ssh-setup-windows.md:8` 的連結為新路徑;確認 `docs/superpowers/` 已無殘留、`git status` 認得 rename(blocked by 2.1)
- [x] 2.4 驗證 CLI 未受影響:`openspec list` 仍回報 active change 狀態正常、`openspec validate --all` 仍 30/30(blocked by 2.1)

## 3. `context/principles.md` 精簡與分組

- [x] 3.1 建立「原 25 條 → 新條目」對照表,每條標明保留 / 併入哪條 / 刪除及理由,寫進 design.md 附錄。**先有對照表再動檔案** —— 它同時是實作依據與驗收依據
- [x] 3.2 依 D2 合併三組自承同源的條目;任一組若合併後長度超過原本兩條之和,回退為分開兩條(blocked by 3.1)
- [x] 3.3 依 D3 刪除三處會過期的斷言與操作指令(blocked by 3.1)
- [x] 3.4 依 D1 加 `##` 分組小標題並重排條目順序;實際為四組而非原估的五組,理由見 design.md 偏離 (c)(blocked by 3.2, 3.3)
- [x] 3.5 更新 frontmatter `description` 使其涵蓋新的分組(blocked by 3.4)

## 4. spec 對齊與收尾驗證

- [x] 4.1 套用 delta 到 `openspec/specs/project-context/spec.md`(凍結記錄歸屬 + 兩個 scenario)
- [x] 4.2 語意不減驗收:逐條對照 `git show HEAD:context/principles.md` 與對照表,確認原 25 條的每個判斷結論都在新版找得到(blocked by 3.4)
- [x] 4.3 `openspec validate --all` 通過;`context/` 仍合 `okf-bundle-conventions`(frontmatter 通過 YAML parser、僅 root `index.md` 帶 `okf_version`)(blocked by 4.1)
- [x] 4.4 全 repo 相對連結檢查:`docs/`、`README.md`、`context/` 內連結全可解析;`openspec/changes/archive/` 下新搬入的三個目錄不納入檢查(凍結記錄,連結失效屬記錄的一部分)(blocked by 2.3)
