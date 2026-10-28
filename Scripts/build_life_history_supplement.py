#!/usr/bin/env python3
"""Offline, attributed supplement; never rewrites FishBase or species selection.

Curated evidence and decisions live in config/, not generated tables. See
docs/life_history_workflow.md for interpretation and independent-review limits.
"""
from __future__ import annotations

import hashlib
import json
import platform
from pathlib import Path

import openpyxl
import pandas as pd
from openpyxl.styles import Alignment

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Output/LifeHistorySupplement'
CONFIG = ROOT / 'config'
PREFIX = 'life_history_supplement_'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def read_csv(path):
    return pd.read_csv(path, dtype=str, keep_default_na=False)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load_sources(root, registry):
    """A missing or altered downloaded snapshot fails the offline build."""
    require(len({s['source_id'] for s in registry}) == len(registry), 'Duplicate source IDs')
    result = []
    for source in registry:
        row = dict(source)
        if source['acquisition'] == 'download':
            path = root / source['archive_path']
            meta = read_json(path.with_suffix(path.suffix + '.metadata.json'))
            require(sha(path) == meta['sha256'], f'Source checksum mismatch: {path}')
            require(meta['requested_url'] == source['url'], f'Source URL mismatch: {path}')
            row.update(sha256=meta['sha256'], retrieved_at=meta['retrieved_at'],
                       resolved_url=meta['resolved_url'], bytes=meta['bytes'])
        result.append(row)
    return pd.DataFrame(result).fillna('')


def validate_evidence(baseline, evidence, sources, policy):
    required = ['evidence_id', 'species', 'source_taxon', 'taxon_match', 'trait',
                'original_value', 'normalized_value', 'unit', 'source_id', 'locator',
                'evidence_text', 'text_type', 'population', 'life_stage', 'sex',
                'season', 'study_period', 'evidence_type', 'method', 'upstream_citation',
                'upstream_inspected', 'source_independence', 'source_inspection',
                'extractor', 'extraction_date', 'reviewer', 'review_status', 'decision',
                'mapping_rule', 'conflict_status', 'applicability']
    require(evidence.evidence_id.is_unique, 'Duplicate evidence IDs')
    for col in required:
        require(col in evidence and evidence[col].map(lambda x: bool(str(x).strip())).all(),
                f'Missing evidence attribution: {col}')
    require(set(evidence.species) <= set(baseline.species), 'Evidence outside frozen roster')
    source_map = sources.set_index('source_id')
    require(set(evidence.source_id) <= set(source_map.index), 'Unknown evidence source')
    require(set(evidence.mapping_rule) <= set(policy['rules']), 'Unknown mapping rule')
    require(set(evidence.decision) <= {'include_contextual', 'hold'}, 'Unknown decision')
    crosswalk = baseline.set_index('species').taxon_match_status
    for row in evidence.to_dict('records'):
        source = source_map.loc[row['source_id']]
        require(bool(source['sha256']) and bool(source['citation']), 'Unarchived/uncited evidence')
        require('withheld' not in crosswalk[row['species']], 'Unresolved taxon transfer')
        require(row['taxon_match'] == 'exact_species' and row['source_taxon'] == row['species']
                or row['taxon_match'].startswith('abbreviated genus expanded'),
                'Taxon match requires an explicit validated crosswalk')
        if row['decision'] == 'include_contextual':
            require(row['mapping_rule'] != 'hold_v1', 'Held evidence cannot be promoted')
            require(not row['trait'].endswith('_hypothesis'), 'Hypothesis cannot be promoted')
            if row['trait'] == 'migration':
                require(row['mapping_rule'] in {'estuary_sea_v1', 'marine_seasonal_v1'},
                        'Migration requires an explicit route mapping')
                expected = {'estuary_sea_v1': 'oceano-estuarine',
                            'marine_seasonal_v1': 'oceanodromous'}[row['mapping_rule']]
                require(row['normalized_value'] == expected, 'Inconsistent migration mapping')
                require(row['conflict_status'] == 'none identified in inspected sources',
                        'Unresolved migration conflict cannot be promoted')


def naf_matches(root, baseline, sources):
    """Keep all reference-level records, including zeros and Undetermined."""
    source = sources.set_index('source_id').loc['NAFMFD']
    frame = pd.read_excel(root / source.archive_path, sheet_name='Query1',
                          dtype=str, keep_default_na=False)
    frame.insert(0, 'source_excel_row', range(2, len(frame) + 2))
    frame['normalized_source_name'] = frame.scientific_name.str.strip()
    matches = []
    for row in baseline.to_dict('records'):
        # Existing crosswalk only. No new cleaning, fuzzy matches, or proxy taxa.
        names = {row['species']}
        if 'withheld' not in row['taxon_match_status'] and row['fishbase_name']:
            names.add(row['fishbase_name'])
        found = frame[frame.normalized_source_name.isin(names)]
        for record in found.to_dict('records'):
            matches.append(dict(species=row['species'],
                taxon_match='exact_project_binomial' if record['normalized_source_name'] == row['species']
                            else 'existing_fishbase_crosswalk',
                fishbase_migration=row['migration'], **record,
                source_id='NAFMFD', source_url=source.url, source_sha256=source.sha256,
                source_citation=source.citation,
                independence_note='shared FishBase upstream reference' if 'fishbase' in record['Reference'].lower()
                                  else 'independence not established',
                decision='crosscheck_only; no automatic vocabulary conversion or overwrite'))
    return pd.DataFrame(matches), dict(raw_rows=len(frame),
        unique_nonblank_source_names=frame.loc[frame.normalized_source_name != '', 'normalized_source_name'].nunique())


def summarize(baseline, evidence, original_evidence):
    summary = baseline.copy()
    included = evidence[evidence.decision == 'include_contextual']
    traits = sorted(set(included.trait) - {'migration'})
    additions = []
    for row in baseline.to_dict('records'):
        sp = row['species']
        part = included[included.species == sp]
        migration = part[part.trait == 'migration']
        require(migration.normalized_value.nunique() <= 1, f'Conflicting promoted migration: {sp}')
        old = original_evidence[(original_evidence.species == sp) & (original_evidence.trait == 'migration')]
        current = row['migration']
        extra = dict(migration_best_available=current,
            migration_best_available_basis='FishBase original' if current else 'unknown',
            migration_best_available_evidence_ids='; '.join(old.evidence_id) if current else '',
            migration_evidence_table='../LifeHistory/trait_evidence.csv' if current else '',
            migration_scope='Original FishBase classification; original review flags apply.' if current else '')
        if not current and not migration.empty:
            extra.update(migration_best_available=migration.iloc[0].normalized_value,
                migration_best_available_basis='project-derived regional interpretation; independent review pending',
                migration_best_available_evidence_ids='; '.join(migration.evidence_id),
                migration_evidence_table='trait_evidence.csv',
                migration_scope=' | '.join(dict.fromkeys(migration.population)))
        for trait in traits:
            selected = part[part.trait == trait]
            # A context-rich summary string avoids implying globally applicable scalar estimates.
            extra['supplement_' + trait] = ' | '.join(
                f"{r.normalized_value} [{r.unit}; {r.population}; {r.life_stage}; {r.sex}]"
                for r in selected.itertuples())
            extra['supplement_' + trait + '_evidence_ids'] = '; '.join(selected.evidence_id)
        extra['supplement_all_evidence_ids'] = '; '.join(evidence.loc[evidence.species == sp, 'evidence_id'])
        extra['supplement_review_status'] = 'independent scientific review pending' if extra['supplement_all_evidence_ids'] else 'no supplementary assignment'
        additions.append(extra)
    result = pd.concat([summary, pd.DataFrame(additions)], axis=1)
    require(result[list(baseline.columns)].equals(baseline), 'Baseline fields changed')
    return result


def gap_review(root, baseline, evidence, summary, reviews):
    gaps = set(baseline.loc[baseline.migration == '', 'species'])
    require(len(reviews) == len(gaps) and {r['species'] for r in reviews} == gaps,
            'Every original migration gap needs exactly one assessment')
    rows, searches = [], []
    for record in reviews:
        sp = record['species']
        ev = evidence[evidence.species == sp]
        require(bool(record['searches']), f'No recorded search: {sp}')
        for query in record['searches']:
            archive = read_json(root / query['archive_path'])
            require(query['query'] in [q['q'] for q in archive.get('queries', [])],
                    f'Search not found in archive: {sp}')
            searches.append(dict(species=sp, **query))
        row = summary[summary.species == sp].iloc[0]
        state = 'regional_route_added' if row.migration_best_available else (
            'classification_interpretation_held' if (ev.trait == 'migration_database_classification').any()
            else 'other_evidence_only' if not ev.empty else 'no_qualifying_route_evidence')
        if 'withheld' in row.taxon_match_status:
            state = 'taxon_unresolved'
        rows.append(dict(species=sp, baseline_migration='',
            migration_best_available=row.migration_best_available, assessment_status=state,
            evidence_ids='; '.join(ev.evidence_id),
            search_archive_paths='; '.join(sorted({q['archive_path'] for q in record['searches']})),
            assessment_note=record['assessment_note'], review_date=record['review_date'],
            review_status=record['review_status']))
    return pd.DataFrame(rows), pd.DataFrame(searches)


def build(root=ROOT, out=None):
    root = Path(root)
    out = Path(out) if out else root / 'Output/LifeHistorySupplement'
    config = root / 'config'
    policy = read_json(config / (PREFIX + 'policy.json'))
    baseline_path = root / policy['baseline_path']
    require(sha(baseline_path) == policy['baseline_sha256'], 'Frozen baseline checksum changed; review before rebasing')
    baseline = read_csv(baseline_path)
    require(len(baseline) == policy['expected_species'] and baseline.species.is_unique, 'Frozen roster invalid')
    require((baseline.migration == '').sum() == policy['expected_migration_gaps'], 'Unexpected baseline gap count')
    sources = load_sources(root, read_json(config / (PREFIX + 'sources.json')))
    evidence = pd.DataFrame(read_json(config / (PREFIX + 'evidence.json'))).fillna('')
    validate_evidence(baseline, evidence, sources, policy)
    evidence = evidence.merge(sources[['source_id', 'citation', 'url', 'archive_path',
                                     'source_version', 'retrieved_at', 'sha256']],
                              on='source_id', how='left', validate='many_to_one')
    evidence['mapping_definition'] = evidence.mapping_rule.map(policy['rules'])
    original_evidence = read_csv(root / 'Output/LifeHistory/trait_evidence.csv')
    summary = summarize(baseline, evidence, original_evidence)
    naf, naf_counts = naf_matches(root, baseline, sources)
    # Pin the held classification to its actual source record, not a handwritten assertion.
    gula = naf[(naf.species == 'Eucinostomus gula') & (naf.source_excel_row == 1561)]
    require(len(gula) == 1 and gula.iloc[0]['Reference assignment'] == 'Semi-anadromous'
            and gula.iloc[0]['Reference'] == 'Stoner 1986', 'NAFMFD held evidence no longer matches source')
    reviews, searches = gap_review(root, baseline, evidence, summary,
                                  read_json(config / (PREFIX + 'gap_review.json')))
    coverage = dict(species=len(baseline), original_migration_present=int((baseline.migration != '').sum()),
        original_migration_missing=int((baseline.migration == '').sum()),
        regional_migration_additions=int(((baseline.migration == '') & (summary.migration_best_available != '')).sum()),
        combined_migration_present=int((summary.migration_best_available != '').sum()),
        combined_migration_missing=int((summary.migration_best_available == '').sum()),
        evidence_records=len(evidence), evidence_species=evidence.species.nunique(),
        included_contextual_records=int((evidence.decision == 'include_contextual').sum()),
        held_records=int((evidence.decision == 'hold').sum()),
        independently_reviewed_supplement_records=0,
        naf_matched_species=naf.species.nunique(), naf_reference_records=len(naf),
        naf_matched_original_gaps=naf[naf.species.isin(reviews.species)].species.nunique(),
        naf_snapshot=naf_counts, gap_review_records=len(reviews),
        interpretation='New route labels are project-derived regional interpretations, not universal species labels or independently reviewed facts.')
    readme = pd.DataFrame([
        ('Scope', 'Frozen 80-species roster; all original FishBase columns retained unchanged.'),
        ('New migration values', 'Four regional project interpretations; original migration column stays blank for these. Independent scientific review pending.'),
        ('Evidence', 'Each supplementary field links to trait_evidence by evidence ID; full citation, locator, archive and context are retained.'),
        ('FishBase evidence', 'Existing values retain their original provenance in the fishbase_evidence sheet and ../LifeHistory/trait_evidence.csv.'),
        ('Held evidence', 'decision=hold entries do not populate trait summaries; see migration_gap_review and naf_match_records.'),
        ('Regions', 'Do not generalize regional observations to all populations, life stages, seasons or sexes.'),
        ('Migration dimensions', 'Route, diel movements, estuarine use and territoriality are separate. No imputation or movement-distance inference.'),
        ('Rebuild', 'python3 Scripts/build_life_history_supplement.py (offline; checks source hashes).'),
        ('Canonical outputs', 'CSV files are canonical; Excel zip timestamps need not be byte-identical.'),
        ('Documentation', 'docs/life_history_workflow.md, Supplement implementation section.'),
    ], columns=['item', 'description'])
    tables = {'life_history_80_species_supplemented': summary, 'trait_evidence': evidence,
              'sources': sources, 'migration_gap_review': reviews,
              'naf_match_records': naf, 'search_log': searches}
    out.mkdir(parents=True, exist_ok=True)
    for name, table in tables.items():
        table.to_csv(out / f'{name}.csv', index=False, lineterminator='\n')
    (out / 'coverage.json').write_text(json.dumps(coverage, indent=2) + '\n')
    workbook = out / 'life_history_80_species_supplemented.xlsx'
    with pd.ExcelWriter(workbook, engine='openpyxl') as writer:
        readme.to_excel(writer, sheet_name='README', index=False)
        for name, table in tables.items():
            table.to_excel(writer, sheet_name='species' if name.startswith('life_history_') else name, index=False)
        original_evidence.to_excel(writer, sheet_name='fishbase_evidence', index=False)
        for ws in writer.book.worksheets:
            ws.freeze_panes = 'C2' if ws.title == 'species' else 'A2'
            ws.auto_filter.ref = ws.dimensions
            for col in ws.columns:
                ws.column_dimensions[col[0].column_letter].width = min(65, max(18, len(str(col[0].value)) + 2))
            for cell in ws[1]:
                cell.alignment = Alignment(wrap_text=True, vertical='top')
    inputs = [baseline_path, root / 'Output/LifeHistory/trait_evidence.csv',
              root / 'config/life_history_taxon_crosswalk.csv',
              root / 'Scripts/build_life_history_supplement.py',
              root / 'Scripts/download_life_history_supplement.py',
              root / 'requirements-life-history.txt']
    inputs += sorted(config.glob(PREFIX + '*.json'))
    inputs += sorted((root / 'Data/LifeHistorySupplement/searches').glob('*.json'))
    for row in sources.to_dict('records'):
        if row['acquisition'] == 'download':
            path = root / row['archive_path']
            inputs += [path, path.with_suffix(path.suffix + '.metadata.json')]
    outputs = sorted(out.glob('*.csv')) + [out / 'coverage.json', workbook]
    manifest = dict(schema_version=policy['schema_version'], command='python3 Scripts/build_life_history_supplement.py',
        python=platform.python_version(), pandas=pd.__version__, openpyxl=openpyxl.__version__,
        inputs={str(p.relative_to(root)): sha(p) for p in inputs},
        outputs={p.name: sha(p) for p in outputs},
        notes='Offline build. Content hashes identify exact code/config/source snapshots. CSVs are canonical. Independent review pending.')
    (out / 'build_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return coverage


if __name__ == '__main__':
    print(json.dumps(build(), indent=2))
