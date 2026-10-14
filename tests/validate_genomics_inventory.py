#!/usr/bin/env python3
"""Validate the completed inventory's identities, evidence, counts and map exclusions."""
import csv
from datetime import date
import hashlib
import gzip
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
    assert not any(yes(s[k]) for k in ('pooled_flag','captive_flag','cell_line_flag','hybrid_flag','possible_duplicate_individual','location_conflict','publication_quality_exclusion'))
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

# Every attached geographic/date value must resolve to evidence for that same sample.
evidence = read('location_provenance')
by_evidence = {r['evidence_id']:r for r in evidence}
sources = {r['source_id']:r for r in read('location_sources')}
assert len(evidence) == len(by_evidence)
checked_hashes = set()
for e in evidence:
    assert (e['species'], e['sample_accession']) in by_sample
    assert e['decision'] and e['decision'] != 'pending'
    assert all(e[f] for f in ('source_url','source_record_id','source_locator','match_method','source_file','source_sha256','retrieved_utc'))
    assert e['source_id'] == 'archive' or e['source_id'] in sources
    assert not e['supporting_source_id'] or e['supporting_source_id'] in sources
    paths, hashes = e['source_file'].split(' | '), e['source_sha256'].split(' | ')
    assert len(paths) == len(hashes)
    for path, expected in zip(paths, hashes):
        if (path, expected) not in checked_hashes:
            assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == expected, path
            checked_hashes.add((path, expected))
    if e['source_id'] != 'archive':
        assert e['publication_doi'] == sources[e['source_id']]['publication_doi']
for source in sources.values():
    assert hashlib.sha256((ROOT/'Data/Genomics/location_sources'/source['file']).read_bytes()).hexdigest() == source['source_sha256']
for s in samples:
    linked = []
    for column in ('location_evidence_ids','date_evidence_ids'):
        for eid in filter(None, s[column].split(' | ')):
            e = by_evidence[eid]
            assert (e['species'],e['sample_accession']) == (s['species'],s['sample_accession'])
            linked.append(e)
    coordinates = [e for e in linked if e['field'] == 'coordinates']
    if s['latitude']:
        assert coordinates and all(e['decision'] != 'withheld_coordinate_conflict' for e in coordinates)
        assert any(abs(float(e['value'])-float(s['latitude'])) < 1e-8 and abs(float(e['value2'])-float(s['longitude'])) < 1e-8 for e in coordinates)
    if s['locality_raw']:
        assert any(e['field'] == 'locality' for e in linked)
    if s['year']:
        assert any(e['field'] == 'collection_year' and int(e['value']) == int(s['year']) for e in linked)
    if s['latitude'] and not s['archive_latitude']:
        assert s['coordinate_scope'] == 'reported_population_site' and yes(s['coordinate_approximate'])
    if yes(s['location_conflict']):
        assert not s['latitude'] and not s['longitude'] and not yes(s['map_candidate'])
        assert any(e['decision'] == 'withheld_coordinate_conflict' for e in coordinates)
    if yes(s['publication_quality_exclusion']):
        assert not yes(s['map_candidate'])

# Accession-specific publication checks, including negative controls and disagreements.
with (ROOT/'Data/Genomics/location_sources/bco854878_samples.csv').open(newline='') as f:
    bco = {r['biosample_accession']:r for r in csv.DictReader(f)}
for e in evidence:
    if e['source_id'] == 'bco854878':
        original = bco[e['sample_accession']]
        assert original['SampleID'] == e['source_record_id']
        assert e['match_method'] == 'exact_BioSample_accession'
        if e['field'] == 'coordinates':
            assert (float(e['value']),float(e['value2'])) == (float(original['lat']),float(original['lon']))
    if e['source_id'].startswith('fundulus_evad123'):
        s = by_sample[(e['species'],e['sample_accession'])]
        assert s['publication_individual_event_id'].endswith('::'+e['source_record_id'])
        assert s['isolate'].rsplit('_Run',1)[0] == e['source_record_id']
cp = [e for e in evidence if e['source_id'].startswith('atherino_evac111') and e['source_record_id'].startswith('CP-') and e['field']=='coordinates']
assert cp and all(e['decision']=='withheld_coordinate_conflict' for e in cp)
for e in cp:
    assert by_sample[(e['species'],e['sample_accession'])]['year'] == ''
assert by_sample[('Menidia menidia','SAMN06436866')]['publication_quality_exclusion'] == 'TRUE'

coverage = read('location_coverage')
assert {r['species'] for r in coverage} == {r['species'] for r in summary}
for row in coverage:
    ws = [s for s in samples if s['species']==row['species'] and int(s['wgs_runs'])>0]
    assert int(row['enriched_coordinates']) == sum(bool(s['latitude']) for s in ws)
    assert int(row['newly_georeferenced']) == sum(bool(s['latitude']) and not s['archive_latitude'] for s in ws)
    assert int(row['mapping_candidates']) == sum(yes(s['map_candidate']) for s in ws)
geome = read('geome_records')
searches = read('geome_searches')
assert len(searches)==80 and all(r['status']=='complete' for r in searches)
assert sum(int(r['sample_records']) for r in searches)==len(geome)
# GEOME discovery leads must not silently attach by species without a sample crosswalk.
assert not any(e['source_id'].startswith('geome') for e in evidence)
for q in read('location_queries'):
    data = gzip.decompress((ROOT/q['cache_path']).read_bytes())
    assert hashlib.sha256(data).hexdigest() == q['sha256']

con = sqlite3.connect(f'file:{OUT / "genomics.sqlite"}?mode=ro', uri=True)
assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
for name in ('species_summary','runs','assemblies','samples','atlas_candidates','sample_attributes','location_provenance','location_sources','location_coverage','geome_records','geome_searches'):
    assert con.execute(f'SELECT count(*) FROM {name}').fetchone()[0] == len(read(name))
assert con.execute('SELECT count(*) FROM atlas_candidates WHERE specimen_count IS NOT NULL').fetchone()[0] == 0
con.close()
assert (OUT/'index.html').is_file()
print(f'Validated 80 species, {len(runs):,} runs, {len(samples):,} sample keys, {len(assemblies)} assemblies, {len(candidates)} mapping candidates and SQLite integrity.')
print(f'Validated {len(evidence):,} location/date assertions, original-source hashes, sample joins, conflicts and GEOME search provenance.')
