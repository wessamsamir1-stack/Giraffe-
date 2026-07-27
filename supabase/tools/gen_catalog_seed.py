#!/usr/bin/env python3
"""
مولّد بذور الأقسام من كتالوج فلاتر.

المصدر الوحيد للحقيقة لشجرة الأقسام هو:
    app/lib/data/catalog/categories.dart

السكريبت ده بيقرأه ويطلّع الـ SQL، عشان الكتالوج في التطبيق وفي قاعدة
البيانات مايفترقوش أبداً. أي تعديل على الأقسام يتعمل في الدارت وبعدها:

    python3 supabase/tools/gen_catalog_seed.py > \
        supabase/migrations/20260727001500_seed_catalog.sql
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DART = ROOT / "app" / "lib" / "data" / "catalog" / "categories.dart"

FEATURED = [
    "mobiles", "electronics", "vehicles", "gaming",
    "furniture", "fashion", "services", "watches",
]

CATEGORY_BLOCK = re.compile(r"static const (\w+) = Category\((.*?)\n  \);", re.S)
SUBCATEGORY = re.compile(
    r"SubCategory\(\s*id: '([^']+)',\s*nameAr: '([^']*)',\s*"
    r"nameEn: (?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")\s*,?\s*\)",
    re.S,
)


def sq(value: str) -> str:
    """اقتباس نص لبوستجرس."""
    return "'" + value.replace("'", "''") + "'"


def unescape(value: str) -> str:
    return value.replace("\\'", "'").replace('\\"', '"')


def main() -> int:
    if not DART.exists():
        print(f"missing source: {DART}", file=sys.stderr)
        return 1

    src = DART.read_text(encoding="utf-8")

    # الترتيب في الدارت هو ترتيب العرض
    order_match = re.search(
        r"static const List<Category> all = \[(.*?)\];", src, re.S
    )
    if not order_match:
        print("could not find the `all` list", file=sys.stderr)
        return 1
    var_order = [v.strip().rstrip(",") for v in order_match.group(1).split() if v.strip(",")]

    blocks: dict[str, tuple] = {}
    for match in CATEGORY_BLOCK.finditer(src):
        var, body = match.group(1), match.group(2)
        cid = re.search(r"id: '([^']+)'", body)
        ar = re.search(r"nameAr: '([^']*)'", body)
        en = re.search(r"nameEn: '([^']*)'", body)
        icon = re.search(r"icon: Icons\.(\w+)", body)
        if not (cid and ar and en and icon):
            continue
        subs = [
            (s.group(1), s.group(2), unescape(s.group(3) or s.group(4) or ""))
            for s in SUBCATEGORY.finditer(body)
        ]
        blocks[var] = (
            cid.group(1),
            ar.group(1),
            en.group(1),
            icon.group(1),
            "restricted: true" in body,
            "isService: true" in body,
            subs,
        )

    ordered = [blocks[v] for v in var_order if v in blocks]
    if not ordered:
        print("no categories parsed", file=sys.stderr)
        return 1

    lines: list[str] = []
    add = lines.append

    add("-- " + "=" * 74)
    add("-- Giraffe — بذور الأقسام")
    add("--")
    add("-- ⚠️  الملف ده **مولّد آلياً**. ممنوع تعديله يدوي.")
    add("--")
    add("--     المصدر: app/lib/data/catalog/categories.dart")
    add("--     المولّد: supabase/tools/gen_catalog_seed.py")
    add("--")
    add(f"-- {len(ordered)} قسم رئيسي · "
        f"{sum(len(c[6]) for c in ordered)} قسم فرعي")
    add("-- " + "=" * 74)
    add("")

    add("insert into public.categories")
    add("  (id, name_ar, name_en, icon, restricted, is_service, is_featured, sort_order)")
    add("values")
    rows = []
    for index, (cid, ar, en, icon, restricted, service, _subs) in enumerate(ordered):
        rows.append(
            f"  ({sq(cid)}, {sq(ar)}, {sq(en)}, {sq(icon)}, "
            f"{str(restricted).lower()}, {str(service).lower()}, "
            f"{str(cid in FEATURED).lower()}, {index * 10})"
        )
    add(",\n".join(rows))
    add("on conflict (id) do update set")
    add("  name_ar     = excluded.name_ar,")
    add("  name_en     = excluded.name_en,")
    add("  icon        = excluded.icon,")
    add("  restricted  = excluded.restricted,")
    add("  is_service  = excluded.is_service,")
    add("  is_featured = excluded.is_featured,")
    add("  sort_order  = excluded.sort_order;")
    add("")

    add("insert into public.subcategories")
    add("  (id, category_id, name_ar, name_en, sort_order)")
    add("values")
    rows = []
    for cid, _ar, _en, _icon, _r, _s, subs in ordered:
        for index, (sid, sar, sen) in enumerate(subs):
            rows.append(
                f"  ({sq(f'{cid}.{sid}')}, {sq(cid)}, {sq(sar)}, "
                f"{sq(sen)}, {index * 10})"
            )
    add(",\n".join(rows))
    add("on conflict (id) do update set")
    add("  category_id = excluded.category_id,")
    add("  name_ar     = excluded.name_ar,")
    add("  name_en     = excluded.name_en,")
    add("  sort_order  = excluded.sort_order;")
    add("")

    sys.stdout.write("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
