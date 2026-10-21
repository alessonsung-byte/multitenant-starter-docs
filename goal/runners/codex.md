# 用 Codex 執行自動開發

> 工作指示在 `goal/自動開發指示.md`，完成條件在 `goal/goal-condition.txt`，兩份都不限工具。本檔只說明 Codex 怎麼啟動。

## 1. 從文件 repo 啟動，並加入另外兩個 repo

```shell
cd multitenant-starter-docs
codex --add-dir ../multitenant-starter-backend --add-dir ../multitenant-starter-frontend
```

- Codex 會自動讀文件 repo 的 `AGENTS.md`，加入的 repo 也會各自讀它們的 `AGENTS.md`
- 不加 `--add-dir` 時，Codex 的 sandbox 通常只允許寫入啟動的資料夾，改不到另外兩個 repo。也可以在 Codex 的 `config.toml` 以 `[sandbox_workspace_write]` 的 `writable_roots` 設定，效果相同
- Codex 合併載入的指示檔有大小上限（預設 32 KiB）。三份 `AGENTS.md` 加起來遠低於上限，但之後擴充守則時要注意，這也是 `00-文件規範.md` 第七節「精簡優先於完整」的原因之一

## 2. 確認 sandbox 允許網路與 Docker

`verify-local.sh` 需要 Docker（後端整合測試、本機資料庫），第一次執行時也需要網路下載 Maven 與 pnpm 依賴。Codex 預設的 sandbox 可能不允許這些操作；如果驗收因為連不到 Docker 或下載失敗，先用 `/permissions` 調整權限，或在 `config.toml` 開啟網路存取，不要讓 agent 修改測試來繞過。

## 3. 填入驗收腳本的 SHA256

```shell
shasum -a 256 goal/verify-local.sh
```

把結果填進 `goal-condition.txt` 的 `<開始 goal 前由人類執行 shasum -a 256 goal/verify-local.sh 填入>`。

## 4. 啟動

在 Codex 中輸入 `/goal`，以 `goal-condition.txt` 的全文作為目標。

Codex 的 `/goal` 由 agent 自己判斷是否完成。`goal-condition.txt` 要求貼出 `verify-local.sh` 的完整輸出（含 SHA256 與 `ALL CHECKS PASSED`），所以結束後**一定要檢查那段輸出**，不要只看 agent 說「完成了」。

## 多個 agent 同時工作時

- 每個 agent 從自己的 worktree 啟動：`cd agents/<任務>/multitenant-starter-docs`，`--add-dir` 指向同一個資料夾裡的後端、前端 worktree（`tasks/README.md` 第 3 節）
- 實作者的完成條件改用 `goal/goal-condition-task.txt`，填入任務卡檔名、任務分支、槽位與兩個工作目錄
- 啟動時直接告訴它角色，例如「你是 T-001 的實作者，任務卡在 tasks/T-001-invoice.md」，它會依 `AGENTS.md` 第 1 節第 5 點去讀 `14-多代理協作規範.md`
