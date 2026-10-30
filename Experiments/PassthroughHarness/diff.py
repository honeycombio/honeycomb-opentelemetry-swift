#!/usr/bin/env python3
"""Diff what the three harness setups sent to the sink.

current      = Honeycomb.configure with defaults, Honeycomb's own instrumentation output
upstream     = bare opentelemetry-swift, upstream's default instrumentation output
passthrough  = Honeycomb.configure with the upstream flags on, upstream's output + Honeycomb config + shapers

usage: diff.py OUTDIR
"""
import json, sys, os
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
BASE = 1_700_000_000
NOISE = {"session.id", "session.previous_id"}  # key must be present, but the value differs per run


def load(mode):
    reqs = [json.loads(l) for l in open(os.path.join(out, mode + ".jsonl")) if l.strip()]
    return reqs


def ids(name):
    return [f["id"] for f in json.load(open(os.path.join(here, name)))["fixtures"]]


hc_ids, up_ids = ids("fixtures-honeycomb.json"), ids("fixtures-upstream.json")
modes = {m: load(m) for m in ("current", "upstream", "passthrough")}


def by_slot(reqs):
    """Return {slot: record} for records stamped with the fixture time encoding, and the rest."""
    slots, rest = {}, []
    for r in reqs:
        for rec in r["records"]:
            t = rec["start"] if rec["signal"] == "spans" else rec.get("time", 0)
            i = t // 1_000_000_000 - BASE
            if rec["signal"] != "metrics" and 0 <= i < 100 and t % 1_000_000_000 == 0:
                slots[(rec["signal"], i)] = rec
            else:
                rest.append(rec)
    return slots, rest


slots = {m: by_slot(r) for m, r in modes.items()}


def keys(rec):
    return set(rec["attributes"])


def status(rec):
    s = rec.get("status") or {}
    return ("ERROR: " + s.get("message", "")) if s.get("code") in (2, "STATUS_CODE_ERROR") else "unset"


print("## Requests on the wire\n")
print("| setup | path | requests | records | header names | content type |")
print("| --- | --- | --- | --- | --- | --- |")
for m, reqs in modes.items():
    agg = {}
    for r in reqs:
        a = agg.setdefault(r["path"], [0, 0, set(), set()])
        a[0] += 1; a[1] += len(r["records"]); a[2] |= set(r["headers"]); a[3].add(r["contentType"])
    for path, (n, k, h, c) in sorted(agg.items()):
        print(f"| {m} | {path} | {n} | {k} | {', '.join(sorted(h))} | {', '.join(sorted(c))} |")

print("\n## Resource attribute keys\n")
res = {}
for m, reqs in modes.items():
    for r in reqs:
        for rec in r["records"]:
            res[m] = set(rec["resource"])
            break
        if m in res: break
print("| key | current | upstream | passthrough |\n| --- | --- | --- | --- |")
for k in sorted(set().union(*res.values())):
    print(f"| `{k}` | " + " | ".join("yes" if k in res[m] else "-" for m in ("current", "upstream", "passthrough")) + " |")

print("\n## Per fixture: current (Honeycomb's own) vs passthrough (upstream + Honeycomb config + shapers) vs upstream raw\n")
total_diff = 0
for i, (hid, uid) in enumerate(zip(hc_ids, up_ids)):
    sig = "spans" if hid.startswith("urlsession") else "logRecords"
    a = slots["current"][0].get((sig, i)); b = slots["upstream"][0].get((sig, i)); c = slots["passthrough"][0].get((sig, i))
    print(f"### `{hid}` (current) ↔ `{uid}` (upstream)\n")
    if not (a and b and c):
        print(f"MISSING: current={bool(a)} upstream={bool(b)} passthrough={bool(c)}\n"); total_diff += 1; continue
    ident = lambda r: f"{r['scope']} / {r.get('name') or r['attributes'].get('name', '')}"
    print(f"- scope / name: current `{ident(a)}`; upstream raw `{ident(b)}`; passthrough `{ident(c)}`")
    if sig == "spans":
        print(f"- status: current `{status(a)}`; upstream raw `{status(b)}`; passthrough `{status(c)}`")
    else:
        print(f"- severity: current `{a.get('severity')}`; upstream raw `{b.get('severity')}`; passthrough `{c.get('severity')}`; event name: current `{a.get('eventName')}`; upstream raw `{b.get('eventName')}`; passthrough `{c.get('eventName')}`")
    ka, kb, kc = keys(a), keys(b), keys(c)
    print(f"- keys only in current vs passthrough: `{sorted(ka - kc)}`")
    print(f"- keys only in passthrough vs current: `{sorted(kc - ka)}`")
    print(f"- keys in upstream raw that differ from current: only-raw `{sorted(kb - ka)}`, only-current `{sorted(ka - kb)}`")
    vd = {k: (a["attributes"][k], c["attributes"][k]) for k in ka & kc if k not in NOISE and a["attributes"][k] != c["attributes"][k]}
    print(f"- shared keys with different values (current, passthrough): `{vd}`")
    same_scope = a["scope"] == c["scope"] and (a.get("name") == c.get("name"))
    same = (ka == kc and not vd and same_scope and (status(a) == status(c) if sig == "spans" else a.get("severity") == c.get("severity")))
    print(f"- **identical shape, current vs passthrough: {'yes' if same else 'NO'}**\n")
    total_diff += 0 if same else 1

print("## Bespoke code with no upstream equivalent (same in current and passthrough)\n")
ra = {(r["scope"], r.get("name") or r["attributes"].get("name", "")): keys(r) for r in slots["current"][1] if r["signal"] != "metrics"}
rc = {(r["scope"], r.get("name") or r["attributes"].get("name", "")): keys(r) for r in slots["passthrough"][1] if r["signal"] != "metrics"}
print("| scope / name | keys equal | keys |\n| --- | --- | --- |")
for k in sorted(set(ra) | set(rc)):
    print(f"| `{k[0]}` / `{k[1]}` | {'yes' if ra.get(k) == rc.get(k) else 'NO'} | `{sorted(ra.get(k) or rc.get(k))}` |")

print("\n## Keys Honeycomb adds on every span (current, passthrough) that bare upstream lacks\n")
ex = [r for r in slots["upstream"][1] if r["signal"] == "spans"][0]
exc = [r for r in slots["current"][1] if r["signal"] == "spans" and r["scope"] == "harness"][0]
print(f"- custom span keys, upstream: `{sorted(keys(ex))}`; current: `{sorted(keys(exc))}`")
print(f"\nfixtures not identical: {total_diff}")
