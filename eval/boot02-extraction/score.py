#!/usr/bin/env python3
"""BOOT-02 證據規格抽取評分。

用法：
    python3 score.py <run_dir> [--expected <expected_dir>] [--json]

比對方式（刻意寬鬆，屬於技術驗證等級，不是正式驗收）：
- 規格配對：依標準答案中 name_keywords 的順序，找第一個名稱含該關鍵字、且尚未被配對的抽取結果。
- 頻率：(unit, interval) 落在 freq_accept 之一；event 與 unknown 不比對 interval。
- 時限：deadline 或 source_text 含 deadline_keywords 之一。
- 產生者：producer.unit 或 producer.role 含 producer_keywords 之一。
- 要素召回：標準答案的每個要素，只要任一抽取要素名稱含其關鍵字之一就算找到。
- 出處：抽取的 sources 與標準答案的 sources 至少重疊一項。
- 問題偵測：抽取的 issue 類型符合，且說明或出處含關鍵字之一。
"""
import json
import re
import sys
from pathlib import Path

CN = {"零": 0, "一": 1, "二": 2, "兩": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}


def cn2int(s: str) -> int:
    if s.isdigit():
        return int(s)
    if s == "十":
        return 10
    if "十" in s:
        a, _, b = s.partition("十")
        return (CN.get(a, 1) if a else 1) * 10 + (CN.get(b, 0) if b else 0)
    return CN.get(s, -1)


def norm_source(s: str) -> str:
    s = str(s).replace(" ", "")
    m = re.search(r"第([0-9一二三四五六七八九十]+)條", s)
    if m:
        return str(cn2int(m.group(1)))
    m = re.search(r"(附表|附件)([0-9一二三四五六七八九十]+)", s)
    if m:
        return f"{m.group(1)}{cn2int(m.group(2))}"
    return s


def has_any(text: str, kws) -> bool:
    return any(k in text for k in kws)


def score_policy(pred: dict, exp: dict) -> dict:
    preds = pred.get("evidence_specs", []) or []
    used = set()
    details = []
    for spec in exp["specs"]:
        match = None
        for kw in spec["name_keywords"]:
            for i, p in enumerate(preds):
                if i not in used and kw in (p.get("name") or ""):
                    match = i
                    break
            if match is not None:
                break
        d = {"id": spec["id"], "label": spec["label"], "required": spec["required"], "matched": match is not None}
        if match is not None:
            used.add(match)
            p = preds[match]
            d["pred_name"] = p.get("name")
            if spec["required"]:
                f = p.get("frequency") or {}
                unit, interval = f.get("unit"), f.get("interval")
                ok = False
                for au, ai in spec.get("freq_accept", []):
                    if unit != au:
                        continue
                    if au in ("event", "unknown") or interval == ai or (interval is None and ai == 1):
                        ok = True
                d["freq_ok"] = ok
                d["freq_pred"] = f"{unit}/{interval}"
                if spec.get("deadline_keywords"):
                    txt = f"{f.get('deadline') or ''} {f.get('source_text') or ''}"
                    d["deadline_ok"] = has_any(txt, spec["deadline_keywords"])
                if spec.get("producer_keywords"):
                    pr = p.get("producer") or {}
                    d["producer_ok"] = has_any(f"{pr.get('unit') or ''} {pr.get('role') or ''}", spec["producer_keywords"])
                srcs = {norm_source(s) for s in (p.get("sources") or [])}
                for el in p.get("required_elements") or []:
                    if isinstance(el, dict) and el.get("source"):
                        srcs.add(norm_source(el["source"]))
                d["source_ok"] = bool(srcs & set(spec.get("sources", [])))
                els = spec.get("elements", [])
                if els:
                    names = [(e.get("name") if isinstance(e, dict) else str(e)) or "" for e in (p.get("required_elements") or [])]
                    found = [e["name"] for e in els if any(has_any(n, e["keywords"]) for n in names)]
                    missing = [e["name"] for e in els if e["name"] not in found]
                    d["element_recall"] = round(len(found) / len(els), 3)
                    d["elements_missing"] = missing
                if spec.get("retention_keywords"):
                    d["retention_ok"] = has_any(str(p.get("retention") or ""), spec["retention_keywords"])
        details.append(d)

    extras = [preds[i].get("name") for i in range(len(preds)) if i not in used]
    distractors = [n for n in extras if has_any(n or "", exp.get("distractor_keywords", []))]

    issues_pred = pred.get("issues", []) or []
    issue_details = []
    for iss in exp.get("issues", []):
        hit = False
        for ip in issues_pred:
            txt = f"{ip.get('description') or ''} {' '.join(map(str, ip.get('sources') or []))}"
            if ip.get("type") in iss["types"] and has_any(txt, iss["keywords"]):
                hit = True
                break
        issue_details.append({"id": iss["id"], "label": iss["label"], "detected": hit, "optional": iss.get("optional", False)})

    req = [d for d in details if d["required"]]
    req_m = [d for d in req if d["matched"]]
    opt_m = [d for d in details if not d["required"] and d["matched"]]

    def rate(key):
        xs = [d[key] for d in req_m if key in d]
        return (sum(1 for x in xs if x), len(xs))

    el = [d["element_recall"] for d in req_m if "element_recall" in d]
    iss_req = [i for i in issue_details if not i["optional"]]
    return {
        "policy_id": exp["policy_id"],
        "spec_recall": (len(req_m), len(req)),
        "spec_precision": (len(req_m) + len(opt_m), len(preds)),
        "freq": rate("freq_ok"),
        "deadline": rate("deadline_ok"),
        "producer": rate("producer_ok"),
        "source": rate("source_ok"),
        "retention": rate("retention_ok"),
        "element_recall_mean": round(sum(el) / len(el), 3) if el else None,
        "issues": (sum(1 for i in iss_req if i["detected"]), len(iss_req)),
        "extras_unmatched": extras,
        "distractor_hits": distractors,
        "details": details,
        "issue_details": issue_details,
    }


def fmt(t):
    a, b = t
    return f"{a}/{b}" + (f" ({a / b:.0%})" if b else "")


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    run = Path(args[0])
    exp_dir = Path(args[args.index("--expected") + 1]) if "--expected" in args else Path(__file__).parent / "expected"
    results = []
    for ef in sorted(exp_dir.glob("*.json")):
        pf = run / ef.name
        if not pf.exists():
            print(f"!! 缺少輸出：{pf}")
            continue
        results.append(score_policy(json.loads(pf.read_text()), json.loads(ef.read_text())))
    if "--json" in args:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return
    tot = {k: [0, 0] for k in ("spec_recall", "spec_precision", "freq", "deadline", "producer", "source", "retention", "issues")}
    for r in results:
        print(f"\n== {r['policy_id']} ==")
        for k in tot:
            tot[k][0] += r[k][0]
            tot[k][1] += r[k][1]
            print(f"  {k:15s} {fmt(r[k])}")
        print(f"  element_recall  {r['element_recall_mean']}")
        for d in r["details"]:
            if d["required"]:
                flag = "✓" if d["matched"] else "✗"
                extra = ""
                if d["matched"]:
                    extra = f" 頻率={d.get('freq_pred')}{'✓' if d.get('freq_ok') else '✗'}"
                    if d.get("elements_missing"):
                        extra += f" 缺要素={d['elements_missing']}"
                print(f"    {flag} {d['label']}{extra}")
        for i in r["issue_details"]:
            print(f"    {'✓' if i['detected'] else '✗'} 問題：{i['label']}{'（選擇性）' if i['optional'] else ''}")
        if r["extras_unmatched"]:
            print(f"    多抽出：{r['extras_unmatched']}")
        if r["distractor_hits"]:
            print(f"    ⚠ 抽到不該抽的：{r['distractor_hits']}")
    els = [r["element_recall_mean"] for r in results if r["element_recall_mean"] is not None]
    print("\n== 總計 ==")
    for k, (a, b) in tot.items():
        print(f"  {k:15s} {fmt((a, b))}")
    if els:
        print(f"  element_recall  {sum(els) / len(els):.3f}")
    print(f"  distractor_hits {sum(len(r['distractor_hits']) for r in results)}")


if __name__ == "__main__":
    main()
