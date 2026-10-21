# tasks/｜本專案的多 agent 操作方式

> 規則見 `14-多代理協作規範.md`（不限專案）；本檔只寫**這個專案**的具體做法。原因見 `03-決策紀錄.md` D-22～D-26。
> 只有一個 agent 時（模式 A）不需要本資料夾，照 `goal/自動開發指示.md` 做即可。

## 1. 這個資料夾放什麼

| 檔案 | 誰寫 | 內容 |
|---|---|---|
| `_範本.md` | — | 任務卡範本 |
| `T-001-xxx.md` | 整合者建立，實作者更新 | 一個任務一張任務卡 |
| `T-001-審查.md` | 審查者 | 審查紀錄（`14` 第 7 節） |
| `<批次名稱>-整合摘要.md` | 整合者 | 給人類審查的摘要（`14` 第 9 節） |

## 2. 需要預先分配的流水號

整合者寫任務卡時，在「預先分配」欄位分配以下號碼（`14` 第 6 節）：

| 流水號 | 位置 | 怎麼看目前用到哪裡 |
|---|---|---|
| 資料庫遷移版本 `V<n>__` | 後端 `codebase/business-service/src/main/resources/db/migration/business/` | 該目錄最大的版本號 |
| E2E 測試編號 `E2E-<nn>` | 前端 `apps/starter/e2e/` | 測試標題最大的編號；新模組從 `E2E-13` 開始（`goal/自動開發指示.md` 5-3） |
| 決策編號 `D-<nn>` | `03-決策紀錄.md` | 不預先分配；實作者只寫提案編號，整合者寫入時決定 |

## 3. 同一台電腦：建立工作目錄（git worktree）

三個 repo 預設放在同一層資料夾。每個 agent 在三個 repo 各建一個 worktree，放在同一個資料夾裡，這樣 repo 之間的相對位置維持不變：

```shell
# 在三個 repo 的上一層執行；T=任務編號與簡稱
T=T-001-invoice
for r in docs backend frontend; do
  git -C multitenant-starter-$r worktree add ../agents/$T/multitenant-starter-$r -b feat/$T main
done
# 前端 worktree 需要自己安裝依賴
(cd agents/$T/multitenant-starter-frontend && pnpm install)
```

- 審查者：用 `git worktree add --detach <路徑> feat/<任務>` 取得實作者的程式碼（同一個分支不能被兩個 worktree 同時 checkout），審查檔寫在 docs repo 的 `review/<任務編號>` 分支
- 整合者：同樣方式建立 `integration/<批次名稱>` 分支的 worktree
- 啟動 AI 工具的方式和單一 agent 相同（`goal/runners/`），只是改從 `agents/<任務>/multitenant-starter-docs` 啟動、`--add-dir` 指向同一個資料夾裡的另外兩個 repo
- 做完後以 `git worktree remove` 移除

## 4. 驗收

```shell
# 在自己的 docs worktree 執行
AGENT_SLOT=<任務卡的槽位> VERIFY_BRANCH=feat/T-001-invoice \
BACKEND=../multitenant-starter-backend FRONTEND=../multitenant-starter-frontend \
bash goal/verify-local.sh
```

| 槽位 | 前端 port | 後端 port | E2E 資料庫 | Redis DB |
|---|---|---|---|---|
| 0（預設，單一 agent） | 4200 | 18080 | `starter_e2e` | 0 |
| N（1～9） | 4200+N×10 | 18080+N | `starter_e2e_N` | N |

- 同一台電腦同時跑驗收的 agent，槽位不可以相同；整合者分配任務卡時一併分配
- PostgreSQL、Redis 容器所有槽位共用（後端 `docker/docker-compose-local.yml`），每個槽位只動自己的資料庫與 Redis DB
- 後端 `./mvnw clean verify` 的整合測試用 Testcontainers，本來就各自獨立
- 雲端 agent 各自有自己的環境，使用槽位 0 即可
- 自動開發的完成條件：實作者用 `goal/goal-condition-task.txt`，整合者合併後以 `VERIFY_BRANCH=integration/<批次名稱>` 執行同一個腳本

## 5. 停工旗標檢查

```shell
# 每一輪開始時，在自己的 docs worktree 執行；有輸出就停止（14 第 8 節）
git show main:STOP.md 2>/dev/null
# 雲端：先 git fetch origin main，再 git show origin/main:STOP.md
```

## 6. 人類審查

- **用 GitHub PR**：整合者推送 `integration/<批次名稱>`（三個 repo 都要），各開一個到 `main` 的 PR
- **用整合摘要**：整合者寫 `tasks/<批次名稱>-整合摘要.md`；人類確認後自己 `git merge --no-ff integration/<批次名稱>`，或明確指示整合者合併
- 合併進 `main` 後，`verify-local.sh` 若有修改，記得重新填 `goal/goal-condition*.txt` 的 SHA256
