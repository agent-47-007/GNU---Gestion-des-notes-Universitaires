#!/usr/bin/env python3
"""Extract the two EC rows per UE from the official programme PDFs.

The generated CSV is a reviewable intermediate; it does not write PostgreSQL.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def text(pdf: Path) -> str:
    result = subprocess.run(["pdftotext", "-layout", str(pdf), "-"], check=True, capture_output=True, text=True)
    return result.stdout


def licence_rows(content: str):
    # Use the official grid, where each child row is directly under its UE.
    start = content.rfind("GRILLE DES ENSEIGNEMENTS DU CYCLE DE LICENCE")
    end = content.find("SYLLABUS DES UNITÉS D’ENSEIGNEMENT", start + 1)
    current_ue = None
    for line in content[start:end].splitlines():
        match = re.match(r"^([A-Z]{3}\d{3,5})\s+(.+?)\s+(Fond|Opt|Comp)\s+.*?\s+(\d+(?:[.,]\d+)?)\s*$", line, re.I)
        if not match:
            continue
        code, title, kind, credits = match.groups()
        if len(code) == 6:
            current_ue = code
        elif current_ue:
            # Child rows occasionally repeat the wrong UE prefix in the PDF.
            # The authoritative relationship is the current parent UE + EC rank.
            code = f"{current_ue}{code[-1]}"
            yield code, title.strip(), credits.replace(",", "."), "Licence 2021"


def master_rows(content: str):
    current = None
    for line in content.splitlines():
        # Some Master headings omit the colon (for example INF472). Accept both forms.
        ue = re.match(r"^INF\s*(\d{3})\s*:?[ \t]+(.*?)\s*\((\d+(?:[.,]\d+)?)\s*crédits?\)", line, re.I)
        if ue:
            current = (f"INF{ue.group(1)}", ue.group(2).strip())
            continue
        ec = re.match(r"^EC([12]):\s*(.*?)\s*\((\d+(?:[.,]\d+)?) crédits?\)", line, re.I)
        if ec and current:
            number, title, credits = ec.groups()
            yield f"{current[0]}{number}", title.strip(), credits.replace(",", "."), "Master 2021"


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_ec_catalogue.py LICENCE.pdf MASTER.pdf", file=sys.stderr)
        return 2
    rows = list(licence_rows(text(Path(sys.argv[1])))) + list(master_rows(text(Path(sys.argv[2]))))
    print("code_m,intitule_matiere,code_ue,rang_ec,credit_matiere,source")
    for code, title, credits, source in rows:
        print(f'"{code}","{title.replace(chr(34), chr(34) * 2)}","{code[:-1]}",{code[-1]},{credits},"{source}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
