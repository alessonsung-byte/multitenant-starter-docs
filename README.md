# Multi-tenant Starter — 專案文件（docs）

這個 repo 是 **Multi-tenant Starter** 三個 repo 之一，放的是「開發之前就先寫好、開發過程中持續維護」的專案文件。
它同時也是一套 **AI 協作的文件驅動開發方法**的完整範例：人類負責決策，Claude（AI）依文件開發，所有決策、架構與變更都有文件可以追溯。

| Repo | 內容 |
|---|---|
| **multitenant-starter-docs**（本 repo） | 需求、決策紀錄、資料庫設計、系統架構、開發計畫、使用者操作說明，以及 AI 開發守則與自動開發腳本 |
| [multitenant-starter-backend](https://github.com/alessonsung-byte/multitenant-starter-backend) | Java 21 · Spring Boot 3.4 · PostgreSQL（Row-Level Security）· Redis · Flyway |
| [multitenant-starter-frontend](https://github.com/alessonsung-byte/multitenant-starter-frontend) | Next.js 14（App Router）· TypeScript · Tailwind CSS · shadcn/ui · Turborepo |

三個 repo 預設放在同一層資料夾：

```
your-workspace/
├── multitenant-starter-docs/       ← 本 repo
├── multitenant-starter-backend/
└── multitenant-starter-frontend/
```

---

## 這套系統是什麼

一個可以直接拿來開發「多個組織共用一套系統、資料互相隔離」的 SaaS 起始專案：

- **租戶（tenant）**：每個組織一個租戶，租戶帳號只看得到自己租戶的資料
- **總管理員**：管理租戶與帳號、檢視所有租戶的資料與跨租戶報表、查看操作紀錄；**只能檢視、不能修改**任何租戶的業務資料
- **範例業務模組**：客戶 → 訂單（只能作廢、不能修改）→ 月報表與 Excel 下載，示範一個完整功能從資料表、API 到畫面的寫法

最主要的設計重點是**多租戶資料隔離做兩層**：程式層由 Hibernate `@TenantId` 自動加上租戶條件，資料庫層再由 PostgreSQL Row-Level Security 擋一次——就算某支 API 漏寫條件、或有人手寫 SQL，資料庫也不會回傳其他租戶的資料。詳細做法見 [13-系統架構設計.md](13-系統架構設計.md) 第二節。

---

## 文件怎麼讀

| 想知道 | 讀 |
|---|---|
| 這個專案是什麼、程式在哪裡、怎麼啟動 | [01-README.md](01-README.md) |
| 要做什麼、給誰用、範圍包含什麼、明確不做什麼 | [02-需求書.md](02-需求書.md) |
| 為什麼選 A 不選 B（含考慮過的替代方案） | [03-決策紀錄.md](03-決策紀錄.md) |
| 資料表長什麼樣子 | [05-資料庫設計.md](05-資料庫設計.md) |
| 怎麼部署到伺服器 | [07-部署手冊.md](07-部署手冊.md) |
| 最近改了什麼 | [09-變更日誌.md](09-變更日誌.md) |
| 接下來做什麼、新增一個業務模組要改哪些地方 | [11-開發計畫.md](11-開發計畫.md) |
| 使用者怎麼操作 | [12-使用者操作說明.md](12-使用者操作說明.md) |
| 系統怎麼組成、每個功能怎麼實作 | [13-系統架構設計.md](13-系統架構設計.md) |

---

## AI 協作的文件驅動開發

這套方法要解決的是「**一個人負責整個專案**」時最常遇到的問題：決策過了三個月就忘記原因、程式改了文件沒跟著改、AI 每次接手都要重新解釋一次背景。

### 文件分三層

| 層 | 文件 | 特性 |
|---|---|---|
| **Layer 0 可攜層** | [`CLAUDE.md`](CLAUDE.md)、[`00-文件規範.md`](00-文件規範.md) | 不含任何專案名詞，**可以原封不動複製到任何新專案**。定義文件怎麼寫、AI 怎麼做事 |
| **Layer 1 專案決策層** | 01、02、03、05、13 | 這個專案的需求、技術選型、架構；每個新專案重新產生 |
| **Layer 2 內容與操作層** | 07、09、11、12 | 上線後持續變動的手冊與紀錄 |

### 幾條關鍵規則

- **決策一定記錄理由與替代方案**（03）：之後情境改變時，才判斷得出要不要重新決策
- **推翻舊決策時保留紀錄**：寫成「取代 某日 的決策」，不直接刪改，下次有人重提舊方案時可以直接查到當初的討論
- **矛盾優先處理**：AI 發現兩份文件矛盾時，立即停下手邊工作、指出矛盾、追溯決策脈絡、等待人類拍板，**先改文件再繼續開發**（`CLAUDE.md` 第 6 節）
- **每次交付都同步更新文件**：依 `00-文件規範.md` 的「更新觸發規則」表格，逐項確認哪些文件要跟著改

### 自動開發（Claude Code `/goal`）

[`goal/`](goal/) 是讓 Claude Code 長時間自主開發的工作框架：

| 檔案 | 用途 |
|---|---|
| [`goal/自動開發指示.md`](goal/自動開發指示.md) | 給 AI 的完整工作指示：範圍、可以自行決定與必須停下來問人的情況、每個階段的完成標準 |
| [`goal/verify-local.sh`](goal/verify-local.sh) | 驗收腳本：後端全部測試、前端 build／lint、啟動前後端跑 E2E、檢查每張租戶資料表都有 RLS、檢查沒有被跳過的測試 |
| [`goal/goal-condition.txt`](goal/goal-condition.txt) | `/goal` 的完成條件：驗收腳本結束碼 0，而且腳本本身的 SHA256 沒被改過（AI 不能為了通過而修改驗收標準） |

完成的唯一判定是**驗收腳本通過**，不是 AI 自己說做完了。

---

## 新專案也想用這套方法

只需要複製 Layer 0 的兩份文件：

```shell
mkdir my-new-project && cd my-new-project
cp ../multitenant-starter-docs/CLAUDE.md ../multitenant-starter-docs/00-文件規範.md .
```

接著請 Claude 讀這兩份文件，從 `02-需求書.md` 開始一起討論；其他文件依 `00-文件規範.md` 的規則在需要時才建立。

---

## 授權

[MIT License](LICENSE)
