#!/usr/bin/env bash
# =====================================================================
# 本地驗收腳本（Claude Code /goal 使用，也可以手動執行）
# 用法：bash goal/verify-local.sh
# 前提：三個 repo 放在同一層資料夾（multitenant-starter-docs／-backend／-frontend），
#       或以環境變數 BACKEND、FRONTEND 指定位置
# 注意：
#   - /goal 執行期間不得修改本檔（第一行輸出的 SHA256 用來確認沒被改過）
#   - 會重建本機 PostgreSQL 中的 starter_e2e 資料庫並清空本機 Redis；不會動到 starter 資料庫（本機開發用）
#   - 執行前請關閉本機開發中的前端（4200 port）與後端（18080 port）
# =====================================================================
set -uo pipefail

DOCS="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="${BACKEND:-$DOCS/../multitenant-starter-backend}"
FRONTEND="${FRONTEND:-$DOCS/../multitenant-starter-frontend}"
WORK="$(mktemp -d)"
FAILED=0
BACKEND_PID=""
FRONTEND_PID=""
FRONTEND_LISTEN_PID=""

echo "verify-local.sh SHA256: $(shasum -a 256 "$0" | cut -d' ' -f1)"
echo "時間：$(date '+%Y-%m-%d %H:%M:%S')"

step() { echo; echo "===== $1 ====="; }
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }

cleanup() {
  [ -n "$BACKEND_PID" ] && kill "$BACKEND_PID" 2>/dev/null
  [ -n "$FRONTEND_PID" ] && kill "$FRONTEND_PID" 2>/dev/null
  # pnpm start 底下的 next-server 是另一個程序，只停外層不會釋放 4200 port，要另外停掉
  [ -n "$FRONTEND_LISTEN_PID" ] && kill $FRONTEND_LISTEN_PID 2>/dev/null
  return 0
}
trap cleanup EXIT

# 必須存在且通過的項目（新增業務模組時在這裡加上它的測試，見 11-開發計畫.md 第二節）
REQ_TESTS="TenantIsolationIT RlsFailClosedIT AccountManagementIT LoginLockoutIT AuditLogIT CustomerOrderApiIT PasswordPolicyTest SalesOrderEntityTest AuditServiceChangesTest"
REQ_E2E="E2E-01 E2E-02 E2E-03 E2E-04 E2E-05 E2E-06 E2E-09 E2E-12"

# ---------------------------------------------------------------------
step "1. 工具與 git 狀態"
for cmd in docker java pnpm node openssl curl shasum lsof; do
  command -v "$cmd" >/dev/null 2>&1 && pass "$cmd" || fail "找不到 $cmd"
done
java -version 2>&1 | grep -q 'version "21' && pass "Java 21" || fail "Java 版本不是 21"
if true; then
  for repo in "$BACKEND" "$FRONTEND"; do
    name="$(basename "$repo")"
    [ "$(git -C "$repo" rev-parse --abbrev-ref HEAD)" = "main" ] && pass "$name 在 main" || fail "$name 不在 main"
    [ -z "$(git -C "$repo" status --porcelain)" ] && pass "$name 工作目錄乾淨" || fail "$name 有未 commit 的變更"
    git -C "$repo" ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.example$' >/dev/null \
      && fail "$name 的 git 中有 .env 檔" || pass "$name 沒有提交 .env 檔"
  done
fi

# ---------------------------------------------------------------------
step "2. 本機 PostgreSQL 與 Redis"
if docker compose -f "$BACKEND/docker/docker-compose-local.yml" up -d --wait >"$WORK/compose.log" 2>&1; then
  pass "容器啟動"
else
  fail "容器啟動失敗"; tail -20 "$WORK/compose.log"
fi
PSQL="docker exec starter-postgres-local psql -U root -d postgres -v ON_ERROR_STOP=1 -tAc"
for db in starter_e2e; do
  $PSQL "DROP DATABASE IF EXISTS $db WITH (FORCE);" >/dev/null && $PSQL "CREATE DATABASE $db;" >/dev/null \
    && pass "重建資料庫 $db" || fail "無法重建資料庫 $db"
done
[ "$($PSQL "SELECT rolsuper FROM pg_roles WHERE rolname='starter_app'")" = "f" ] \
  && pass "執行用帳號 starter_app 存在且不是 superuser" || fail "starter_app 不存在或是 superuser"
docker exec starter-redis-local redis-cli FLUSHALL >/dev/null && pass "清空 Redis" || fail "無法清空 Redis"

# ---------------------------------------------------------------------
step "3. 後端建置與測試（./mvnw clean verify）"
if (cd "$BACKEND/codebase" && ./mvnw -B clean verify) >"$WORK/maven.log" 2>&1; then
  pass "mvnw clean verify 結束碼 0"
else
  fail "mvnw clean verify 失敗"; grep -E "ERROR|FAIL" "$WORK/maven.log" | head -30
fi
cat >"$WORK/check-junit.js" <<'JS'
const fs = require("fs"), path = require("path");
const [root, ...required] = process.argv.slice(2);
const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === "node_modules" || e.name.startsWith(".")) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (/^TEST-.*\.xml$/.test(e.name) && /(surefire|failsafe)-reports/.test(p)) files.push(p);
  }
})(root);
const suites = {}; let total = 0, broken = 0;
for (const f of files) {
  const head = (fs.readFileSync(f, "utf8").match(/<testsuite\b[^>]*>/) || [""])[0];
  const num = (k) => Number((head.match(new RegExp(" " + k + "=\"(\\d+)\"")) || [0, 0])[1]);
  const name = ((head.match(/ name="([^"]+)"/) || [])[1] || "").split(".").pop();
  const s = { tests: num("tests"), bad: num("failures") + num("errors"), skipped: num("skipped") };
  suites[name] = s; total += s.tests; broken += s.bad;
}
let ok = total > 0 && broken === 0;
console.log("  後端測試總數 " + total + "，失敗 " + broken);
for (const c of required) {
  const s = suites[c];
  if (!s || s.tests === 0) { console.log("  [FAIL] 缺少測試類別或沒有任何測試：" + c); ok = false; }
  else if (s.bad > 0 || s.skipped > 0) { console.log("  [FAIL] " + c + " 有失敗或被跳過的測試"); ok = false; }
  else console.log("  [PASS] " + c + "（" + s.tests + " 個測試）");
}
process.exit(ok ? 0 : 1);
JS
node "$WORK/check-junit.js" "$BACKEND/codebase" $REQ_TESTS || FAILED=1

# ---------------------------------------------------------------------
step "4. 前端安裝、建置、lint"
if (cd "$FRONTEND" && pnpm install --frozen-lockfile && NEXT_PUBLIC_BASE_PATH=/starter pnpm build && pnpm lint) >"$WORK/frontend.log" 2>&1; then
  pass "pnpm install／build／lint"
else
  fail "前端建置或 lint 失敗"; tail -40 "$WORK/frontend.log"
fi

# ---------------------------------------------------------------------
step "5. 啟動前後端並執行 E2E（Playwright）"
lsof -nP -iTCP:18080 -sTCP:LISTEN >/dev/null 2>&1 && fail "18080 port 已被使用"
JAR="$BACKEND/codebase/api-server/target/api-server.jar"
if [ "$FAILED" = "0" ] && [ -f "$JAR" ]; then
  APP_JWT_KEY="$(openssl rand -base64 32)" \
  APP_JASYPT_PASSWORD=verify-local \
  APP_DB_NAME=starter_e2e \
  APP_DB_USERNAME=starter_app APP_DB_PASSWORD=starter_app_local \
  APP_FLYWAY_USERNAME=root APP_FLYWAY_PASSWORD=starter_owner_local \
  API_SERVER_PORT=18080 \
  API_SERVER_LOG_FILE_NAME="$WORK/api-server.log" \
  java -jar "$JAR" >"$WORK/backend.out" 2>&1 &
  BACKEND_PID=$!
  for _ in $(seq 1 120); do curl -sf http://localhost:18080/ping >/dev/null && break; sleep 1; done
  curl -sf http://localhost:18080/ping >/dev/null && pass "後端啟動（使用 starter_app 帳號連線）" \
    || { fail "後端 120 秒內沒有啟動"; tail -40 "$WORK/backend.out"; }

  PORT_4200_WAS_FREE=1
  if lsof -tiTCP:4200 -sTCP:LISTEN >/dev/null 2>&1; then
    PORT_4200_WAS_FREE=0
    fail "4200 port 已被佔用（請先關掉開發中的前端或上次留下的 next-server）"
  fi
  (cd "$FRONTEND/apps/starter" && \
    NEXT_PUBLIC_BASE_PATH=/starter \
    API_PREFIX=http://localhost:18080 \
    SECRET_KEY="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=')" \
    SESSION_KEY=STARTER_E2E COOKIE_SECURE=false NODE_ENV=production \
    pnpm start) >"$WORK/frontend-server.log" 2>&1 &
  FRONTEND_PID=$!
  for _ in $(seq 1 60); do curl -sf http://localhost:4200/starter/login >/dev/null && break; sleep 1; done
  # 只記錄這次自己啟動的 next-server，不會停掉別的程式
  [ "$PORT_4200_WAS_FREE" = "1" ] && FRONTEND_LISTEN_PID="$(lsof -tiTCP:4200 -sTCP:LISTEN 2>/dev/null)"
  curl -sf http://localhost:4200/starter/login >/dev/null && pass "前端啟動" \
    || { fail "前端 60 秒內沒有啟動"; tail -20 "$WORK/frontend-server.log"; }
else
  fail "前面的步驟失敗或找不到 ${JAR}，略過 E2E"
fi

if [ "$FAILED" = "0" ]; then
  rm -f "$FRONTEND/apps/starter/e2e-results.json"
  (cd "$FRONTEND" && E2E_BASE_URL=http://localhost:4200/starter pnpm --filter starter e2e) >"$WORK/e2e.log" 2>&1
  cat >"$WORK/check-e2e.js" <<'JS'
const fs = require("fs");
const [file, ...required] = process.argv.slice(2);
if (!fs.existsSync(file)) { console.log("  [FAIL] 找不到 E2E 報告 " + file); process.exit(1); }
const report = JSON.parse(fs.readFileSync(file, "utf8"));
const specs = [];
(function walk(suites) {
  for (const s of suites || []) { for (const sp of s.specs || []) specs.push(sp); walk(s.suites); }
})(report.suites);
let ok = specs.length > 0;
const failed = specs.filter((s) => !s.ok);
console.log("  E2E 測試總數 " + specs.length + "，失敗 " + failed.length);
for (const s of failed) { console.log("  [FAIL] " + s.title); ok = false; }
for (const id of required) {
  const s = specs.find((sp) => sp.title.startsWith(id));
  if (!s) { console.log("  [FAIL] 缺少 E2E 測試 " + id); ok = false; }
  else if (s.ok) console.log("  [PASS] " + s.title);
}
process.exit(ok ? 0 : 1);
JS
  node "$WORK/check-e2e.js" "$FRONTEND/apps/starter/e2e-results.json" $REQ_E2E || { FAILED=1; tail -40 "$WORK/e2e.log"; }
fi

# ---------------------------------------------------------------------
step "6. 資料庫隔離設定檢查（starter_e2e）"
DBQ="docker exec starter-postgres-local psql -U root -d starter_e2e -v ON_ERROR_STOP=1 -tAc"
NO_RLS="$($DBQ "SELECT c.relname FROM pg_class c
  WHERE c.relkind='r' AND c.relnamespace='public'::regnamespace AND c.relname <> 'mt_user'
    AND EXISTS (SELECT 1 FROM information_schema.columns col
                WHERE col.table_schema='public' AND col.table_name=c.relname AND col.column_name='tenant_id')
    AND NOT (c.relrowsecurity AND c.relforcerowsecurity
             AND EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid=c.oid))" 2>&1)"
[ -z "$NO_RLS" ] && pass "所有含 tenant_id 的資料表都啟用並強制 RLS、有 policy" || fail "以下資料表沒有完整的 RLS：$NO_RLS"
OWNED="$($DBQ "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tableowner='starter_app'" 2>&1)"
[ -z "$OWNED" ] && pass "starter_app 不是任何資料表的擁有者" || fail "starter_app 擁有資料表：$OWNED"
TENANT_TABLES="$($DBQ "SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND column_name='tenant_id' AND table_name <> 'mt_user'" 2>&1)"
echo "  含 tenant_id 的資料表數：$TENANT_TABLES"
[ "${TENANT_TABLES:-0}" -ge 1 ] 2>/dev/null && pass "已有屬於租戶的資料表" || fail "沒有任何屬於租戶的資料表"

# ---------------------------------------------------------------------
# ---------------------------------------------------------------------
step "7. 程式規範"
LOGS="$(grep -rn "console\.log" "$FRONTEND/apps/starter" "$FRONTEND/packages" \
  --include=*.ts --include=*.tsx --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist --exclude-dir=e2e 2>/dev/null)"
[ -z "$LOGS" ] && pass "前端沒有 console.log" || { fail "前端有 console.log"; echo "$LOGS" | head; }
SKIPS="$(grep -rnE "@Disabled|test\.skip|test\.only|describe\.skip" \
  "$BACKEND/codebase" "$FRONTEND/apps/starter/e2e" --include=*.java --include=*.ts 2>/dev/null)"
[ -z "$SKIPS" ] && pass "沒有被停用或跳過的測試" || { fail "有被停用或跳過的測試"; echo "$SKIPS" | head; }

# ---------------------------------------------------------------------
step "8. 文件"
grep -qE "待確認 #|建議，待確認" "$DOCS/13-系統架構設計.md" && fail "13 仍有待確認的設計點" || pass "13 沒有待確認的設計點"
[ -s "$DOCS/12-使用者操作說明.md" ] && pass "12-使用者操作說明 存在" || fail "缺少 12-使用者操作說明.md"

# ---------------------------------------------------------------------
echo
if [ "$FAILED" = "0" ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "CHECKS FAILED（記錄檔在 ${WORK}）"
  exit 1
fi
