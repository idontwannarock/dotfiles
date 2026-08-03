## 1. context/ 文件擴充

- [x] 1.1 `context/glossary.md` 的 **cross-tool parity / name-map wrapper** 條目就地擴充,補上鏈的三個具名檔案與從屬關係,並指向既有的 **`~/.agent` shared body** 條目(不重述其內容)。驗收:條目數不變、`grep -c '^- \*\*' context/glossary.md` 與改前相同。
- [x] 1.2 `context/principles.md`「跨平台與跨工具部署」組的 **跨工具 parity = shared body + 薄指標** 條目就地擴充,補上接新工具的前置檢查(先確認該工具實際的 instruction-file 慣例,不要假設檔名)。驗收:條目數改前 == 改後,四個 `##` 分組標題與各組成員不變(不用絕對數字當判準 —— 數字型斷言本身會 drift)。

## 2. 驗收

- [x] 2.1 `openspec validate --all` 綠燈。
- [x] 2.2 確認未觸及 `.chezmoiroot` 之下的 source:`git diff --name-only` 不含 `home/` 任何路徑,故不需 `chezmoi apply`。

## 3. Sync 與收尾(archive 階段)

- [x] 3.1 `openspec-sync-specs`:將 `specs/project-context/spec.md` 的 ADDED requirement 摺回 `openspec/specs/project-context/spec.md`。
- [ ] 3.2 `openspec-archive-change`。
- [ ] 3.3 **PR 合併後**才回收 memory:刪 `~/.claude/memory/-home-howardwang-ws-github-dotfiles/project-cross-tool-targets.md`,同時刪 `MEMORY.md` 對應索引行。驗收:`MEMORY.md` 每一行指向的檔案都存在。
