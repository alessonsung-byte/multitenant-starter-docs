# 01｜README（專案總覽）

## 專案是什麼

**Multi-tenant Starter**：多個組織（租戶）共用一套網頁系統、資料互相隔離的起始專案。
包含帳號與租戶管理、兩層資料隔離（程式層＋資料庫層）、操作紀錄、一個完整的範例業務模組（客戶、訂單、月報表），以及從本機開發到伺服器部署的設定。
新的業務功能照範例模組的寫法加上去即可，步驟見 `11-開發計畫.md`「新增一個業務模組」。

需求與範圍見 `02-需求書.md`；技術選型與原因見 `03-決策紀錄.md`；系統怎麼組成見 `13-系統架構設計.md`。

## 目前狀態（2026-10-20）

- 帳號與多租戶、範例業務模組（客戶、訂單、月報表、跨租戶報表）、操作紀錄、本機示範資料、伺服器 Docker 部署設定都已完成
- 後端有整合測試證明兩個租戶互相拿不到對方的資料（`TenantIsolationIT`），以及資料庫層在沒有程式保護時仍然擋得住（`RlsFailClosedIT`）
- 前端有 Playwright E2E 測試涵蓋主要流程與手機版面

## 程式碼位置

三個 repo 放在同一層資料夾：

| 項目 | 位置 | 說明 |
|---|---|---|
| 文件 | `multitenant-starter-docs/`（本 repo） | 本文件所在的 repo |
| 後端 | `multitenant-starter-backend/` | Java 21＋Spring Boot 3.4＋Maven 多模組＋PostgreSQL＋Redis＋Flyway；啟動方式見該 repo 的 `README.md` |
| 前端 | `multitenant-starter-frontend/` | Next.js 14 App Router，Turborepo（pnpm）；啟動方式見該 repo 的 `README.md` |

- 本機網址：前端 `http://localhost:4200/starter`、後端 `http://localhost:8080`
- 伺服器部署的 Docker 設定：前端映像檔 `multitenant-starter-frontend/Dockerfile`；前端＋後端＋PostgreSQL＋Redis 的 compose 檔 `multitenant-starter-backend/docker/docker-compose-server.yml`，步驟見 `07-部署手冊.md`
- 預設帳號：`admin`／初始密碼 `admin`（總管理員，第一次登入時系統會要求修改密碼）
- 本機示範資料（後端 Spring profile `local`）：`admin`／`Starter-Admin-2026`、`tenant_a_user`／`Starter-TenantA-2026`、`tenant_b_user`／`Starter-TenantB-2026`，兩個示範租戶各有幾筆客戶與訂單
- 資料庫帳號：建表帳號（Flyway，資料表擁有者）與後端執行用的 `starter_app` 分開，原因見 `03-決策紀錄.md` D-04
- 自動化測試：後端 `./mvnw clean verify`（需要 Docker）；前端 E2E `pnpm --filter starter e2e`；整套本地驗收 `bash goal/verify-local.sh`（多個 agent 同時驗收時加上 `AGENT_SLOT=1`～`9` 錯開 port 與資料庫，見 `tasks/README.md` 第 4 節）

## 文件怎麼讀

依照 `AGENTS.md` 第 1 節的順序：先讀 `00-文件規範.md`，再讀 `03-決策紀錄.md`，再讀 `02-需求書.md`；要知道系統怎麼組成、每個功能怎麼實作，讀 `13-系統架構設計.md`；要知道接下來做什麼，讀 `11-開發計畫.md`；要知道最近改了什麼，讀 `09-變更日誌.md`。

## 這個 repo 沒有的文件

`00-文件規範.md` 列出的文件中，以下幾份這個專案目前不需要：

| 文件 | 為什麼沒有 |
|---|---|
| `04-現有系統盤點.md` | 這是全新的起始專案，沒有要取代的既有系統。拿來改造既有系統時再建立 |
| `06-內容素材.md` | 沒有對外的文案內容 |
| `08-維運手冊.md` | 上線後依實際遇到的狀況再建立；目前的日常操作寫在 `07-部署手冊.md`「日常操作」 |
| `10-內容合規規範.md` | 起始專案不屬於任何特定產業 |
