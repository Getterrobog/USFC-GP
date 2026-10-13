#!/usr/bin/env python3
"""Validate the completed inventory's identities, evidence, counts and map exclusions."""
import csv
from datetime import date
import hashlib
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Output/Genomics'

def read(name):
    with (OUT / (name + '.csv')).open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))

def yes(value):
    return value == 'TRUE'

summary, samples, runs, assemblies, candidates = [read(x) for x in ('species_summary','samples','runs','assemblies','atlas_candidates')]
assert len(summary) == 80 and len({r['species'] for r in summary}) == 80
assert len(samples) == len({(r['species'],r['sample_accession']) for r in samples})
assert len(runs) == len({(r['species'],r['run_accession']) for r in runs})
assert len(assemblies) == len({(r['species'],r['assembly_accession']) for r in assemblies})
by_sample = {(r['species'],r['sample_accession']):r for r in samples}
for r in runs + assemblies:
    if r['sample_accession']:
        assert (r['species'],r['sample_accession']) in by_sample
assert sum(int(r['wgs_runs']) for r in summary) == sum(yes(r['wgs_eligible']) for r in runs)
assert sum(int(r['wgs_samples']) for r in summary) == sum(int(r['wgs_runs']) > 0 for r in samples)
assert sum(int(r['mapped_dated_samples']) for r in summary) == len(candidates)
for c in candidates:
    s = by_sample[(c['species'],c['sample_accession'])]
    assert 1930 < int(c['year']) <= date.today().year
    assert -100 <= float(c['longitude']) <= -50 and 5 <= float(c['latitude']) <= 60
    assert float(c['cell_lon']) == float(c['longitude']) // 2 * 2
    assert float(c['cell_lat']) == float(c['latitude']) // 2 * 2
    assert c['specimen_count'] == '' and c['sample_count'] == '1' and c['count_unit'] == 'BioSample_accession'
    assert not any(yes(s[k]) for k in ('pooled_flag','captive_flag','cell_line_flag','hybrid_flag','possible_duplicate_individual'))
    assert yes(s['map_candidate']) and int(s['wgs_runs']) > 0
for s in samples:
    if s['date_status'] != 'single_year':
        assert s['year'] == ''
    if s['coordinate_status'] in ('missing','conflicting_coordinates','unparsed_or_invalid'):
        assert s['latitude'] == '' and s['longitude'] == ''
for a in assemblies:
    if a['assembly_status'] != 'current':
        assert a['annotation_available'] == 'FALSE'
assert by_sample[('Menidia menidia', 'SAMN06436420')]['captive_flag'] == 'TRUE'
assert by_sample[('Clupea harengus', 'SAMN33007718')]['pooled_flag'] == 'TRUE'
for r in summary:
    if r['species'] == 'Myctophum opalinum':
        assert r['wgs_availability'] == 'unknown_taxonomy'
for entry in read('input_checksums'):
    assert hashlib.md5((ROOT/entry['path']).read_bytes()).hexdigest() == entry['md5'], entry['path']
con = sqlite3.connect(f'file:{OUT / "genomics.sqlite"}?mode=ro', uri=True)
assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
for name in ('species_summary','runs','assemblies','samples','atlas_candidates','sample_attributes'):
    assert con.execute(f'SELECT count(*) FROM {name}').fetchone()[0] == len(read(name))
assert con.execute('SELECT count(*) FROM atlas_candidates WHERE specimen_count IS NOT NULL').fetchone()[0] == 0
con.close()
assert (OUT/'index.html').is_file()
print(f'Validated 80 species, {len(runs):,} runs, {len(samples):,} sample keys, {len(assemblies)} assemblies, {len(candidates)} mapping candidates and SQLite integrity.')
