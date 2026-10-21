# 用 Claude Code 執行自動開發

> 工作指示在 `goal/自動開發指示.md`，完成條件在 `goal/goal-condition.txt`，兩份都不限工具。本檔只說明 Claude Code 怎麼啟動。

## 1. 從文件 repo 啟動，並加入另外兩個 repo

```shell
cd multitenant-starter-docs
claude --add-dir ../multitenant-starter-backend --add-dir ../multitenant-starter-frontend
```

- Claude Code 會自動讀文件 repo 的 `CLAUDE.md`，再由它匯入 `AGENTS.md`
- 後端、前端 repo 的 `AGENTS.md` 不依賴工具自動載入：`AGENTS.md` 第 1 節與 `自動開發指示.md` 第 0 節都要求 agent 自己去讀
- 不加 `--add-dir` 時，Claude Code 無法修改另外兩個 repo

## 2. 填入驗收腳本的 SHA256

```shell
shasum -a 256 goal/verify-local.sh
```

把結果填進 `goal-condition.txt` 的 `<開始 goal 前由人類執行 shasum -a 256 goal/verify-local.sh 填入>`。

## 3. 啟動

在 Claude Code 中輸入 `/goal`，以 `goal-condition.txt` 的全文作為完成條件。

## 4. 建議：用權限設定擋住禁止事項

`自動開發指示.md` 第 3-3 節的禁止事項只靠文字約束。想要強制擋住時，可以在 Claude Code 的權限設定把 `git push`（模式 A；多 agent 時只能擋推送主分支，`14-多代理協作規範.md` 第 10 節）、修改 `goal/verify-local.sh` 與 `goal/自動開發指示.md` 設為拒絕。這是個人或專案的工具設定，不屬於規範本身。

## 多個 agent 同時工作時

- 每個 agent 從自己的 worktree 啟動：`cd agents/<任務>/multitenant-starter-docs`，`--add-dir` 指向同一個資料夾裡的後端、前端 worktree（`tasks/README.md` 第 3 節）
- 實作者的完成條件改用 `goal/goal-condition-task.txt`，填入任務卡檔名、任務分支、槽位與兩個工作目錄
- 啟動時直接告訴它角色，例如「你是 T-001 的實作者，任務卡在 tasks/T-001-invoice.md」，它會依 `AGENTS.md` 第 1 節第 5 點去讀 `14-多代理協作規範.md`
