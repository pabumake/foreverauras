#!/usr/bin/env python3
"""Build a WeakAuras import string ("!WA:1!" = AceSerializer + raw deflate + LibDeflate print-encoding).

Usage: python3 tools/build_import.py auras/<name>/aura.py
The aura.py file must define `AURA` (dict) or `AURAS` (dict of name -> aura dict, writes import-<name>.txt each); with an extra `GROUP` (parent group dict) it also writes import-group.txt with every AURAS entry as a child and may define `CUSTOM_TEXT` etc. already inlined.
Writes import.txt next to it.
"""
import sys, zlib, runpy, re
from pathlib import Path

ALPHA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()"


def ser(v) -> bytes:
    if isinstance(v, bool): return b"^B" if v else b"^b"
    if v is None: return b"^Z"
    if isinstance(v, (int, float)): return b"^N" + repr(v).encode()
    if isinstance(v, str):
        out = bytearray(b"^S")
        for b in v.encode("utf-8"):
            if b == 30: out += b"~z"
            elif b <= 32: out += b"~" + bytes([b + 64])
            elif b == 94: out += b"~}"
            elif b == 126: out += b"~|"
            elif b == 127: out += b"~{"
            else: out.append(b)
        return bytes(out)
    if isinstance(v, dict):
        out = bytearray(b"^T")
        for k, x in v.items():
            out += ser(k) + ser(x)
        return bytes(out + b"^t")
    if isinstance(v, list):  # lua array, 1-indexed
        return ser({i + 1: x for i, x in enumerate(v)})
    raise TypeError(type(v))


def encode_print(data: bytes) -> str:
    out, cache, bits = [], 0, 0
    for b in data:
        cache |= b << bits
        bits += 8
        while bits >= 6:
            out.append(ALPHA[cache & 63]); cache >>= 6; bits -= 6
    if bits: out.append(ALPHA[cache & 63])
    return "".join(out)


def decode_print(s: str) -> bytes:
    out, cache, bits = bytearray(), 0, 0
    for c in s:
        cache |= ALPHA.index(c) << bits
        bits += 6
        while bits >= 8:
            out.append(cache & 255); cache >>= 8; bits -= 8
    return bytes(out)


def build(aura: dict, children: list | None = None) -> str:
    """children: list of aura dicts -> group import (aura is the parent group; the importer links them)."""
    payload = {"m": "d", "d": aura, "v": 1421, "s": "5.19.0"}
    if children:
        payload["c"] = children
    raw = b"^1" + ser(payload) + b"^^"
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    comp = c.compress(raw) + c.flush()
    return "!WA:1!" + encode_print(comp)


if __name__ == "__main__":
    src = Path(sys.argv[1])
    ns = runpy.run_path(str(src))
    # aura.py defines either AURA (-> import.txt) or AURAS = {"name": aura, ...} (-> import-<name>.txt each)
    targets = {"import.txt": (ns["AURA"], None)} if "AURA" in ns else {f"import-{k}.txt": (v, None) for k, v in ns["AURAS"].items()}
    # optional GROUP (a parent group dict) + AURAS: one extra import containing the group and all children
    if "GROUP" in ns and "AURAS" in ns:
        targets["import-group.txt"] = (ns["GROUP"], list(ns["AURAS"].values()))
    for fname, (aura, children) in targets.items():
        s = build(aura, children)
        # self-check: round trip
        back = zlib.decompress(decode_print(s[6:]), -15)
        assert back.startswith(b"^1^T") and back.endswith(b"^t^^")
        (src.parent / fname).write_text(s + "\n")
        print(f"wrote {src.parent/fname} ({len(s)} chars)")
