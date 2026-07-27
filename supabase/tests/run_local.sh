#!/usr/bin/env bash
# =============================================================================
# Giraffe — تصريف واختبار السكيما على بوستجرس محلي
#
# بيعمل قاعدة نضيفة من الصفر، يركّب بديل سكيما auth، يشغّل كل المهاجرات
# بالترتيب، وبعدها يشغّل اختبارات الدخان.
#
# الاستخدام:
#   ./supabase/tests/run_local.sh            # تصريف + اختبار
#   ./supabase/tests/run_local.sh --schema   # تصريف بس
#
# متطلبات: PostgreSQL 14+ شغال. المتغيرات دي بتتظبط من البيئة:
#   PGHOST (افتراضي /tmp) · PGPORT (55432) · PGUSER (postgres)
# =============================================================================
set -euo pipefail

PGHOST="${PGHOST:-/tmp}"
PGPORT="${PGPORT:-55432}"
PGUSER="${PGUSER:-postgres}"
DB="${DB:-giraffe}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL=(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -v ON_ERROR_STOP=1 -q)

echo "▶ إعادة إنشاء قاعدة $DB"
"${PSQL[@]}" -d postgres -c "drop database if exists $DB with (force);" >/dev/null
"${PSQL[@]}" -d postgres -c "create database $DB;" >/dev/null

echo "▶ بديل سكيما auth (محلي فقط — ممنوع على سوبابيز)"
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/tests/00_auth_stub.sql" >/dev/null

echo "▶ تشغيل المهاجرات"
for f in "$ROOT"/supabase/migrations/*.sql; do
  printf '   %s\n' "$(basename "$f")"
  "${PSQL[@]}" -d "$DB" -f "$f" >/dev/null
done

if [[ "${1:-}" == "--schema" ]]; then
  echo "✔ السكيما اتصرّفت بنجاح"
  exit 0
fi

echo "▶ اختبارات الدخان"
for f in "$ROOT"/supabase/tests/[1-9]*.sql; do
  [[ -e "$f" ]] || continue
  printf '   %s\n' "$(basename "$f")"
  "${PSQL[@]}" -d "$DB" -f "$f"
done

echo "✔ كل الاختبارات نجحت"
