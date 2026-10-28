#!/usr/bin/env python3
"""Offline inventory of legacy selection inputs; does not select species or fix data.

Run from any directory with Python 3.10+ (standard library only).
Raw date categories deliberately avoid guessing centuries or treating dates as verified.
"""
import argparse
import csv
import hashlib
import io
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


def read_csv(path):
    raw = path.read_bytes()
    try:
        text = raw.decode("utf-8-sig")
        encoding = "utf-8-sig"
    except UnicodeDecodeError:
        # Inventory only: this is a reversible decoding hypothesis, not a correction.
        text = raw.decode("cp1252")
        encoding = "cp1252_provisional_requires_confirmation"
    reader = csv.DictReader(io.StringIO(text, newline=""))
    rows = list(reader)
    if not reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
        raise ValueError(f"Missing or duplicate headers: {path}")
    if any(None in row or None in row.values() for row in rows):
        raise ValueError(f"Malformed CSV row: {path}")
    return rows, reader.fieldnames, encoding


def date_class(value):
    """Classify only explicit years before parenthetical annotations; no date repair."""
    text = value.strip()
    if not text:
        return "missing"
    years = [int(y) for y in re.findall(r"(?<!\d)(?:18|19|20)\d{2}(?!\d)", text.split("(")[0])]
    if not years:
        return "no_explicit_four_digit_year"
    if min(years) >= 1880 and max(years) <= 1929:
        return "explicit_years_within_1880_1929"
    if max(years) < 1880 or min(years) > 1929:
        return "explicit_years_outside_1880_1929"
    return "explicit_years_cross_1880_1929_boundary"


def write_csv(path, rows, fields):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def audit(root, out):
    paths = sorted(list((root / "Data").glob("*.csv")) + list((root / "Output/Files").glob("*.csv")))
    tables, inventory = {}, []
    for path in paths:
        rows, fields, encoding = read_csv(path)
        rel = path.relative_to(root).as_posix()
        tables[rel] = rows
        key = next((k for k in ["Catalog Number - USNM", "Catalog.Number...USNM", "Lot #"] if k in fields), None)
        ids = Counter(r[key] for r in rows if r[key].strip()) if key else Counter()
        inventory.append(dict(path=rel, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                              rows=len(rows), columns=len(fields), encoding=encoding,
                              catalog_key=key or "", unique_nonempty_catalog_keys=len(ids) if key else "",
                              repeated_catalog_keys=sum(n > 1 for n in ids.values()) if key else "",
                              excess_catalog_rows=sum(n - 1 for n in ids.values()) if key else ""))

    raw = tables["Data/All_collections.csv"]
    retained = tables["Output/Files/All_Ships_Updated.csv"]
    removed = tables["Output/Files/Removed_lots.csv"]
    potential = tables["Output/Files/Potential.csv"]
    raw_index = defaultdict(list)
    for row in raw:
        raw_index[row["Catalog Number - USNM"]].append(row)
    potential_ids = Counter(r["Catalog.Number...USNM"] for r in potential)
    diagnostics, species_rows, cluster_rows = [], defaultdict(list), defaultdict(list)
    for number, row in enumerate(potential, 1):
        label = row["Populations.by.species"]
        match = re.fullmatch(r"Population \d+ of (.+)", label)
        if not match:
            raise ValueError(f"Unrecognized legacy cluster label: {label}")
        species = match.group(1)
        key = row["Catalog.Number...USNM"]
        originals = raw_index.get(key, [])
        # Ambiguous matches stay ambiguous. Never pick the first of repeated keys.
        original = originals[0] if len(originals) == 1 else None
        diagnostic = dict(
            potential_data_row=number, species=species, legacy_cluster=label, catalog_number=key,
            potential_rows_for_catalog=potential_ids[key], raw_rows_for_catalog=len(originals),
            legacy_specimen_count=row["Specimen.Count"], legacy_date=row["Date.Collected"],
            raw_date=original["Date Collected"] if original else "",
            raw_date_class=date_class(original["Date Collected"]) if original else "ambiguous_or_missing_raw_join",
            raw_coordinate_pair_missing=(int(not original["Centroid Latitude"].strip() or not original["Centroid Longitude"].strip()) if original else ""),
            legacy_cluster_diameter_km=row["Spatial.distance"],
            raw_country=original["Country"] if original else "",
            raw_province_state=original["Province/State"] if original else "",
        )
        diagnostics.append(diagnostic)
        species_rows[species].append(diagnostic)
        cluster_rows[label].append(diagnostic)

    candidate_summary = []
    for species, rows in sorted(species_rows.items()):
        classes = Counter(r["raw_date_class"] for r in rows)
        candidate_summary.append(dict(
            species=species, legacy_candidate_rows=len(rows), unique_catalog_keys=len({r["catalog_number"] for r in rows}),
            legacy_clusters=len({r["legacy_cluster"] for r in rows}),
            legacy_specimen_sum_unverified=sum(int(r["legacy_specimen_count"]) for r in rows),
            raw_date_within_1880_1929_rows=classes["explicit_years_within_1880_1929"],
            raw_date_missing_rows=classes["missing"],
            raw_date_no_four_digit_year_rows=classes["no_explicit_four_digit_year"],
            raw_join_ambiguous_or_missing_rows=classes["ambiguous_or_missing_raw_join"],
            raw_coordinates_missing_rows=sum(r["raw_coordinate_pair_missing"] == 1 for r in rows),
            max_legacy_cluster_diameter_km=max(float(r["legacy_cluster_diameter_km"]) for r in rows),
        ))
    candidate_names = {r["Valid.Name"] for r in tables["Output/Files/CandidateSpeciesList.csv"]}
    summary_names = {r["Species"] for r in tables["Output/Files/Species_summary_table.csv"]}
    raw_ids = Counter(r["Catalog Number - USNM"] for r in raw)
    accounted = Counter(r["Catalog.Number...USNM"] for r in retained + removed)
    stats = dict(
        scope="Offline descriptive audit of legacy artifacts; not eligibility, abundance, or biological population inference",
        raw_rows=len(raw), retained_rows=len(retained), removed_rows=len(removed),
        retained_plus_removed_equal_raw_rows=len(retained) + len(removed) == len(raw),
        retained_plus_removed_catalog_multiset_equals_raw=accounted == raw_ids,
        raw_preservation_method_nonempty=sum(bool(r["Preservation Method"].strip()) for r in raw),
        raw_date_classes=dict(sorted(Counter(date_class(r["Date Collected"]) for r in raw).items())),
        potential_rows=len(potential), potential_unique_catalog_keys=len(potential_ids),
        potential_repeated_catalog_keys=sum(n > 1 for n in potential_ids.values()),
        potential_legacy_species=len(species_rows), potential_legacy_clusters=len(cluster_rows),
        candidate_names_match_potential=candidate_names == set(species_rows),
        candidates_absent_from_summary=sorted(candidate_names - summary_names),
        summary_names_absent_from_candidates=sorted(summary_names - candidate_names),
        candidate_raw_date_classes=dict(sorted(Counter(r["raw_date_class"] for r in diagnostics).items())),
        candidate_rows_missing_raw_coordinates=sum(r["raw_coordinate_pair_missing"] == 1 for r in diagnostics),
        legacy_clusters_with_diameter_over_40km=sum(max(float(r["legacy_cluster_diameter_km"]) for r in rows) > 40 for rows in cluster_rows.values()),
        max_legacy_cluster_diameter_km=max(float(r["legacy_cluster_diameter_km"]) for r in diagnostics),
    )
    out.mkdir(parents=True, exist_ok=True)
    write_csv(out / "input_inventory.csv", inventory, list(inventory[0]))
    write_csv(out / "legacy_candidate_diagnostics.csv", diagnostics, list(diagnostics[0]))
    write_csv(out / "legacy_species_summary.csv", candidate_summary, list(candidate_summary[0]))
    (out / "audit_summary.json").write_text(json.dumps(stats, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    # Fingerprint non-CSV evidence as well as audited tables. No generated outputs included.
    evidence = paths + sorted((root / "Scripts").glob("*.R")) + sorted((root / "Scripts").glob("*.py"))
    evidence += [root / "background/one_page_proposal.txt", root / "R-USFCGP.Rproj"]
    evidence += sorted((root / "Data").glob("*.xlsx"))
    manifest = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(evidence)}
    (out / "source_sha256.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return stats


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Output directory; defaults to Output/SelectionAudit")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stats = audit(root, args.output or root / "Output/SelectionAudit")
    print(json.dumps(stats, indent=2, sort_keys=True))
