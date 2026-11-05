#!/usr/bin/env python3
"""Extract the two EC rows per UE from the official programme PDFs.

The generated CSV is a reviewable intermediate; it does not write PostgreSQL.
"""
from __future__ import annotations

import re
import subprocess
import sys
import csv
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
        match = re.match(r"^([A-Z]{3}\d{3,5})\s+(.+?)\s+(Fond|Opt|Comp|SIGL|SR|SDD|Sécu)\s+.*?\s+(\d+(?:[.,]\d+)?)\s*$", line, re.I)
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
    grid_start = content.rfind("GRILLE DES ENSEIGNEMENTS DU CYCLE DE MASTER")
    syllabus_start = content.find("SYLLABUS DES UNITÉS D’ENSEIGNEMENT", grid_start)
    grid = content[grid_start:syllabus_start]
    syllabus = content[syllabus_start:]
    credits_by_ue = {}
    rows_by_code = {}
    current_ue = None
    child_rank = 0
    for line in grid.splitlines():
        row = re.match(
            r"^\s*(INF\d{3})\s+.+?\s+(?:Fond|SIGL|SR|SDD|Sécu)\s+.*?\s+(\d+(?:[.,]\d+)?)\s*$",
            line,
            re.I,
        )
        if row:
            code, credits = row.groups()
            credits_by_ue[code] = float(credits.replace(",", "."))
            current_ue = code
            child_rank = 0
            continue
        child = re.match(
            r"^\s{3,}(.+?)\s+(?:Fond|SIGL|SR|SDD|Sécu)\s+.*?\s+(\d+(?:[.,]\d+)?)\s*$",
            line,
            re.I,
        )
        if child and current_ue:
            child_rank += 1
            title, credits = child.groups()
            code = f"{current_ue}{child_rank}"
            rows_by_code[code] = (
                code,
                title.strip(),
                f"{float(credits.replace(',', '.')):g}",
                "Master 2021",
            )

    current = None
    for line in syllabus.splitlines():
        # Use the UE code to reset context even when the descriptive heading omits credits.
        ue = re.match(r"^INF\s*(\d{3})\s*:?[ \t]+", line, re.I)
        if ue:
            code = f"INF{ue.group(1)}"
            current = (code, credits_by_ue.get(code))
            continue
        ec = re.match(r"^EC([12])\s*:?\s*(.*?)(?:\s*\((\d+(?:[.,]\d+)?)\s*crédits?\))?\s*$", line, re.I)
        if ec and current and current[1] is not None:
            number, title, credits = ec.groups()
            code = f"{current[0]}{number}"
            if code not in rows_by_code:
                value = float(credits.replace(",", ".")) if credits else current[1] / 2
                rows_by_code[code] = (code, title.strip(), f"{value:g}", "Master 2021")

    yield from rows_by_code.values()


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_ec_catalogue.py LICENCE.pdf MASTER.pdf", file=sys.stderr)
        return 2
    rows = list(licence_rows(text(Path(sys.argv[1])))) + list(master_rows(text(Path(sys.argv[2]))))
    ue_catalogue = Path(__file__).with_name("ue_catalogue.csv")
    with ue_catalogue.open(encoding="utf-8-sig", newline="") as stream:
        ue_order = {row["code_ue"]: i for i, row in enumerate(csv.DictReader(stream))}
    rows.sort(key=lambda row: (ue_order.get(row[0][:-1], len(ue_order)), int(row[0][-1])))
    print("code_m,intitule_matiere,code_ue,rang_ec,credit_matiere,source")
    for code, title, credits, source in rows:
        print(f'"{code}","{title.replace(chr(34), chr(34) * 2)}","{code[:-1]}",{code[-1]},{credits},"{source}"')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
