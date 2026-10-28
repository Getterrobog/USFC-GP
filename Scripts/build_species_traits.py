#!/usr/bin/env python3
"""Build an offline relational evidence database for the frozen 80 fish species.

Reuses FishBase and the documented supplement. No new name cleaning, imputation,
live IUCN claims, or genomic-response analysis. See docs/life_history_workflow.md.
"""
from __future__ import annotations
import hashlib
import json
import platform
import sqlite3
import math
import re
from pathlib import Path

import pandas as pd
import openpyxl
import pyarrow.parquet as pq

ROOT = Path(__file__).resolve().parents[1]
VERSION = '26.06'
RAW = ROOT / 'Data/LifeHistory/raw' / ('v' + VERSION)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def csv(path):
    return pd.read_csv(path, dtype=str, keep_default_na=False)


def present(value):
    return value is not None and not pd.isna(value) and str(value).strip() != ''


def val(value):
    if not present(value):
        return ''
    if hasattr(value, 'item'):
        value = value.item()
    return str(value)


def identifier(value):
    return str(int(float(value))) if present(value) and float(value) > 0 else ''


def require(condition, message):
    if not condition:
        raise ValueError(message)


def dump(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


GROUPS = {'mainly animals (troph. 2.8 and up)': 'mainly animals',
          'plants/detritus+animals (troph. 2.2-2.79)': 'plants/detritus and animals',
          'mainly plants/detritus (troph. 2-2.19)': 'mainly plants/detritus'}
GUILDS = {'gc': 'generalised carnivores', 'hd': 'herbivores/detritivores',
          'is': 'sessile invertivores', 'mi': 'mobile invertivores',
          'om': 'omnivores', 'pk': 'planktivores'}
SOCIAL = {'sol': 'solitary', 'pair': 'pairs', 'smallg': 'groups of 3–10',
          'medg': 'groups of 10–20', 'largeg': 'groups of more than 20'}
SPAWN = {'pelagic': 'pelagic', 'attach': 'attached', 'demersal': 'demersal',
         'live': 'livebearers (source category)', 'oral': 'oral'}
EVCOLS = ['evidence_id', 'species', 'source_taxon', 'trait', 'value', 'unit',
          'value_numeric', 'value_min', 'value_max',
          'evidence_type', 'source_id', 'locator', 'reference_scope',
          'upstream_citation', 'upstream_url', 'definition', 'context_json',
          'qc_flags', 'decision', 'review_status', 'mapping_rule']


class Database:
    def __init__(self):
        self.sources = {}
        self.evidence = {}
        self.links = []

    def add(self, evidence_id, species, trait, value, source_id, locator, **kw):
        require(source_id in self.sources, 'Unknown source: ' + source_id)
        require(present(value) and bool(locator), 'Empty value or locator')
        row = dict.fromkeys(EVCOLS, '')
        row.update(evidence_id=evidence_id, species=species, source_taxon=species,
                   trait=trait, value=val(value), unit='category', source_id=source_id,
                   locator=locator, evidence_type='database_reported',
                   reference_scope='source record; primary trait reference unverified',
                   context_json='{}', decision='include_contextual',
                   review_status='independent scientific review pending', mapping_rule='direct transcription')
        try:
            number = float(value)
            if math.isfinite(number):
                row['value_numeric'] = number
        except (ValueError, TypeError):
            pass
        row.update(kw)
        if evidence_id in self.evidence:
            # Existing records are reused, never counted as new independent evidence.
            old = self.evidence[evidence_id]
            require(old['species'] == species and old['value'] == val(value), 'Evidence ID collision')
            old.update(kw)
        else:
            self.evidence[evidence_id] = row
        return evidence_id

    def link(self, table, species, field, ids):
        for key in ids:
            require(key in self.evidence and self.evidence[key]['species'] == species,
                    'Broken summary evidence link')
            self.links.append(dict(summary_table=table, species=species, field=field, evidence_id=key))


def load_inputs(db):
    policy = read_json(ROOT / 'config/species_traits_policy.json')
    base_path = ROOT / policy['baseline_path']
    require(sha(base_path) == policy['baseline_sha256'], 'Frozen baseline changed')
    base = csv(base_path)
    require(len(base) == 80 and base.species.is_unique, 'Invalid frozen roster')
    crosswalk = csv(ROOT / 'Output/LifeHistory/taxon_crosswalk.csv')
    require(list(crosswalk.species) == list(base.species), 'Taxon crosswalk order/roster changed')
    manifest = read_json(RAW / 'download_manifest.json')
    tables = {}
    for name, meta in manifest.items():
        path = RAW / (name + '.parquet')
        require(meta['version'] == VERSION and sha(path) == meta['sha256'], 'FishBase source changed: ' + name)
        tables[name] = pq.read_table(path).to_pandas(timestamp_as_object=True)
        db.sources['FB_' + name] = dict(source_id='FB_' + name,
            citation=f'Froese, R., and Pauly, D. (eds). FishBase, release {VERSION}, {name} table; versioned parquet archive distributed through rfishbase/source.coop.',
            url=meta['url'], archive_path=str(path.relative_to(ROOT)), version=VERSION,
            sha256=meta['sha256'], retrieved_at=meta['retrieved_utc'],
            source_type='FishBase_snapshot', reference_scope='field-specific references retained where supplied; otherwise record-level fallback')
    # Use the prior supplement's manifest rather than silently accepting edited exports.
    supp_dir = ROOT / 'Output/LifeHistorySupplement'
    sm = read_json(supp_dir / 'build_manifest.json')
    for name in ['trait_evidence.csv', 'sources.csv', 'life_history_80_species_supplemented.csv']:
        require(sha(supp_dir / name) == sm['outputs'][name], 'Supplement output changed: ' + name)
    for row in csv(supp_dir / 'sources.csv').to_dict('records'):
        if not row['sha256']:
            continue
        path = ROOT / row['archive_path']
        require(sha(path) == row['sha256'], 'Supplement source changed')
        db.sources['SUP_' + row['source_id']] = dict(source_id='SUP_' + row['source_id'],
            citation=row['citation'], url=row['url'], archive_path=row['archive_path'],
            version=row['source_version'], sha256=row['sha256'], retrieved_at=row['retrieved_at'],
            source_type='previous_supplement', reference_scope='curated locator; upstream inspection status in evidence')
    for row in read_json(ROOT / 'config/species_traits_sources.json'):
        path = ROOT / row['archive_path']
        meta = read_json(path.with_suffix(path.suffix + '.metadata.json'))
        require(sha(path) == meta['sha256'] and meta['requested_url'] == row['url'], 'New source changed: ' + row['source_id'])
        db.sources[row['source_id']] = {**row, 'sha256': meta['sha256'], 'retrieved_at': meta['retrieved_at']}
    return base, crosswalk, tables, policy


def import_previous(db, base):
    old = csv(ROOT / 'Output/LifeHistory/trait_evidence.csv')
    for row in old.to_dict('records'):
        db.add(row['evidence_id'], row['species'], row['trait'], row['value'],
            'FB_' + row['source_table'],
            f"{row['source_table']} row {row['source_row_id']}; {row['source_field']}",
            source_taxon=row['fishbase_name'], unit=row['unit'], evidence_type=row['evidence_type'],
            reference_scope=row['reference_scope'], upstream_citation='FishBase reference ' + row['selected_reference_id'] if row['selected_reference_id'] else 'not supplied',
            upstream_url=row['reference_url'], context_json=row['source_context_json'] or '{}',
            qc_flags=row['qc_flags'], decision='hold' if row['qc_flags'] else 'include_contextual',
            review_status=row['primary_source_review'])
    for row in csv(ROOT / 'Output/LifeHistorySupplement/trait_evidence.csv').to_dict('records'):
        db.add(row['evidence_id'], row['species'], row['trait'], row['normalized_value'],
            'SUP_' + row['source_id'], row['locator'], source_taxon=row['source_taxon'],
            unit=row['unit'], evidence_type=row['evidence_type'], definition=row['evidence_text'],
            upstream_citation=row['upstream_citation'], reference_scope='curated passage',
            context_json=dump(row), decision=row['decision'], mapping_rule=row['mapping_rule'],
            review_status=row['review_status'])
    require(set(old.species) <= set(base.species), 'Previous evidence outside roster')
    return old


def raw_record(db, sp, source_taxon, table, row, field, trait, unit='category', ref='',
               fallback='', kind='database_reported', definition='', positive_only=False):
    value = row.get(field)
    if not present(value) or positive_only and float(value) != -1:
        return ''
    ids = {'species': 'SpecCode', 'ecology': 'autoctr', 'reproduc': 'autoctr', 'stocks': 'StockCode'}
    rowid = identifier(row[ids[table]])
    oldid = f'{sp}|{table}|{rowid}|{field}'
    key = oldid if oldid in db.evidence else f'EXT|{oldid}'
    direct = identifier(row.get(ref)) if ref else ''
    back = identifier(row.get(fallback)) if fallback else ''
    selected = direct or back
    context = {k: val(v) for k, v in row.items() if present(v)}
    db.add(key, sp, trait, value, 'FB_' + table, f'{table}.{ids[table]}={rowid}; {field}',
        source_taxon=source_taxon, unit=unit, evidence_type=kind, definition=definition,
        context_json=dump(context), reference_scope='field' if direct else 'record_fallback' if back else 'database field; upstream reference absent',
        upstream_citation='FishBase reference ' + selected if selected else 'not supplied',
        upstream_url='https://www.fishbase.se/references/FBRefSummary.php?ID=' + selected if selected else '')
    return key


def enrich_fishbase(db, base, crosswalk, tables):
    iucn, trophic, functional = [], [], []
    for tax in crosswalk.to_dict('records'):
        sp = tax['species']
        attached = tax['attach_traits'] == '1'
        status = dict(species=sp, source_taxon=tax['fishbase_name'] if attached else '',
            taxon_match_status=tax['match_status'], iucn_category_reported='',
            iucn_raw_code='', assessment_date='', criteria='', taxon_id='', assessment_id='',
            assessment_url='', assessment_scope='not verified', verification='taxon unresolved' if not attached else 'pending',
            current_latest_verified='false', evidence_id='', assessment_review_evidence_ids='')
        tr = dict(species=sp, fishbase_feeding_group='', fishbase_feeding_group_raw='',
            feeding_group_evidence_ids='', feeding_mechanism='', feeding_mechanism_evidence_ids='',
            trophic_level_diet='', trophic_level_diet_se='', trophic_level_food_items='',
            trophic_level_food_items_se='', trophic_level_preferred='', trophic_level_method='',
            trophic_level_evidence_id='', trophic_level_se='', trophic_level_se_evidence_id='',
            trophic_level_context='', reef_diet_guild='', reef_diet_guild_evidence_ids='',
            source_comparison='not compared', contextual_diet_guild='', contextual_diet_guild_evidence_ids='')
        fn = dict(species=sp, body_shape='', body_shape_evidence_ids='',
            schooling_reported='', schooling_evidence_ids='', activity_reported='', activity_evidence_ids='',
            mating_system='', mating_system_evidence_ids='', batch_spawning_reported='', batch_spawning_evidence_ids='',
            spawning_aggregation_reported='', spawning_aggregation_evidence_ids='')
        if attached:
            code = int(float(tax['attached_spec_code']))
            sr = tables['species'].loc[tables['species'].SpecCode == code]
            require(len(sr) == 1, 'Source taxon missing/duplicate')
            sr = sr.iloc[0]
            source_taxon = sr.Genus + ' ' + sr.Species
            require(source_taxon == tax['fishbase_name'], 'Taxon source mismatch')
            shape = raw_record(db, sp, source_taxon, 'species', sr, 'BodyShapeI', 'body_shape',
                               fallback='SpeciesRefNo', definition='FishBase external body-shape category; record reference is not necessarily trait-specific.')
            fn.update(body_shape=val(sr.BodyShapeI), body_shape_evidence_ids=shape)
            db.link('functional_traits', sp, 'body_shape', [shape] if shape else [])
            stocks = tables['stocks']
            general = stocks[(stocks.SpecCode == code) & (stocks.Level == 'species in general')]
            require(len(general) == 1, 'Expected exactly one species-in-general stock')
            stock = general.iloc[0]
            key = raw_record(db, sp, source_taxon, 'stocks', stock, 'IUCN_Code', 'iucn_category_reported',
                kind='IUCN_status_carried_by_FishBase', definition='Category carried in pinned FishBase release; not live IUCN verification.')
            raw = val(stock.IUCN_Code)
            code_value = raw if raw in {'EX','EW','CR','EN','VU','NT','LC','DD'} else ''
            require(raw in {'EX','EW','CR','EN','VU','NT','LC','DD','N.E.'}, 'Unrecognized Red List code')
            tid, aid = identifier(stock.IUCN_ID), identifier(stock.IUCN_IDAssess)
            status.update(iucn_category_reported=code_value, iucn_raw_code=raw,
                assessment_date=val(stock.IUCN_DateAssessed), criteria=val(stock.IUCN_Assessment),
                taxon_id=tid, assessment_id=aid,
                assessment_url=f'https://www.iucnredlist.org/species/{tid}/{aid}' if tid and aid else '',
                assessment_scope='species in general in FishBase; IUCN geographic scope not independently checked',
                verification='FishBase-carried assessment; latest unverified' if code_value else 'FishBase reports N.E.; current IUCN evaluation status unverified',
                evidence_id=key)
            if aid == '162704857':
                status['assessment_scope'] = 'Global'
                status['verification'] = 'Category/date/scope corroborated in public indexed IUCN assessment text; latest unverified'
            for field in ['iucn_category_reported','iucn_raw_code','assessment_date','criteria','taxon_id','assessment_id']:
                if status[field]:
                    db.link('iucn_status', sp, field, [key])
            eco = tables['ecology']
            # Restrict preferred estimates to this species-level stock, never the first arbitrary population.
            selected = eco[(eco.SpecCode == code) & (eco.StockCode == stock.StockCode)]
            require(len(selected) <= 1, 'Multiple species-level ecology records need review')
            if not selected.empty:
                er = selected.iloc[0]
                for field, outfield, trait, ref in [
                    ('Herbivory2','fishbase_feeding_group','fishbase_feeding_group','HerbivoryRef'),
                    ('FeedingType','feeding_mechanism','feeding_mechanism','FeedingTypeRef')]:
                    k = raw_record(db, sp, source_taxon, 'ecology', er, field, trait,
                                   ref=ref, fallback='EcologyRefNo', kind='database_classification')
                    if k:
                        value = val(er[field]).strip()
                        if field == 'Herbivory2':
                            require(value in GROUPS, 'Unknown feeding group')
                            tr['fishbase_feeding_group_raw'] = value
                            value = GROUPS[value]
                        tr[outfield] = value
                        tr['feeding_group_evidence_ids' if field == 'Herbivory2' else 'feeding_mechanism_evidence_ids'] = k
                        db.link('trophic_traits', sp, outfield, [k])
                for field, label, ref in [('DietTroph','diet','DietRef'), ('FoodTroph','food_items','FoodRef')]:
                    k = raw_record(db, sp, source_taxon, 'ecology', er, field, field, 'trophic level', ref=ref,
                        fallback='EcologyRefNo', kind='derived_trophic_estimate',
                        definition='Diet-composition estimate' if field == 'DietTroph' else 'Food-item estimate; see source remarks for resampling/single-item basis')
                    if not k:
                        continue
                    require(1 <= float(er[field]) <= 6, 'Implausible trophic estimate')
                    sefield = 'DietSeTroph' if field == 'DietTroph' else 'FoodSeTroph'
                    sek = raw_record(db, sp, source_taxon, 'ecology', er, sefield, sefield,
                        'trophic-level standard error', ref=ref, fallback='EcologyRefNo', kind='estimate_uncertainty')
                    if sek:
                        require(float(er[sefield]) >= 0, 'Negative trophic SE')
                    tr['trophic_level_' + label] = val(er[field])
                    tr['trophic_level_' + label + '_se'] = val(er.get(sefield))
                    db.link('trophic_traits', sp, 'trophic_level_' + label, [k])
                    if sek:
                        db.link('trophic_traits', sp, 'trophic_level_' + label + '_se', [sek])
                    if not tr['trophic_level_preferred']:
                        tr.update(trophic_level_preferred=val(er[field]), trophic_level_method=label,
                            trophic_level_evidence_id=k, trophic_level_se=val(er.get(sefield)),
                            trophic_level_se_evidence_id=sek,
                            trophic_level_context=val(er.get('DietRemark' if field == 'DietTroph' else 'FoodRemark')))
                        db.link('trophic_traits', sp, 'trophic_level_preferred', [k])
                        if sek:
                            db.link('trophic_traits', sp, 'trophic_level_se', [sek])
                k = raw_record(db, sp, source_taxon, 'ecology', er, 'Schooling', 'schooling_reported',
                    ref='SchoolShoalRef', fallback='EcologyRefNo', positive_only=True,
                    definition='Positive source flag only; zero is not treated as evidence of absence.')
                if k:
                    fn.update(schooling_reported='yes; source life-stage context retained', schooling_evidence_ids=k)
                    db.link('functional_traits', sp, 'schooling_reported', [k])
                k = raw_record(db, sp, source_taxon, 'ecology', er, 'Circadian1', 'activity_reported',
                               ref='CircadianRef', fallback='EcologyRefNo')
                if k:
                    fn.update(activity_reported=val(er.Circadian1), activity_evidence_ids=k)
                    db.link('functional_traits', sp, 'activity_reported', [k])
            rr = tables['reproduc']
            rr = rr[(rr.SpecCode == code) & (rr.StockCode == stock.StockCode)]
            for field, trait, ref, positive in [('MatingSystem','mating_system','MatingRefNo',False),
                    ('BatchSpawner','batch_spawning_reported','SpawnModRef',True),
                    ('SpawnAgg','spawning_aggregation_reported','SpawnAggRef',True)]:
                keys = [raw_record(db, sp, source_taxon, 'reproduc', r, field, trait,
                    ref=ref, fallback='ReproducRefNo', positive_only=positive) for _,r in rr.iterrows()]
                keys = [k for k in keys if k]
                if keys:
                    fn[trait] = 'yes; source positive flag' if positive else '; '.join(sorted({db.evidence[k]['value'] for k in keys}))
                    idfield = {'mating_system':'mating_system_evidence_ids','batch_spawning_reported':'batch_spawning_evidence_ids','spawning_aggregation_reported':'spawning_aggregation_evidence_ids'}[trait]
                    fn[idfield] = '; '.join(keys)
                    db.link('functional_traits', sp, trait, keys)
        iucn.append(status); trophic.append(tr); functional.append(fn)
    return pd.DataFrame(iucn), pd.DataFrame(trophic), pd.DataFrame(functional)


def enrich_reef(db, crosswalk, trophic, functional, base):
    path = ROOT / db.sources['ATLANTIC_REEF_V2']['archive_path']
    reef = pd.read_excel(path, sheet_name='traits&distributions', dtype=str, keep_default_na=False)
    reef.insert(0, 'excel_row', range(2, len(reef) + 2))
    reef['match_name'] = reef.species.str.strip().str.replace('_', ' ', regex=False)
    # The release contains duplicate Cerdale floridana rows outside our roster.
    # Preserve that audit; fail only if a project taxon has multiple matches.
    source_issues=reef.loc[reef.match_name.duplicated(keep=False),['species','excel_row','match_name']].copy()
    source_issues=source_issues.rename(columns={'species':'source_species'})
    source_issues['issue']='duplicate source taxon; no automatic deduplication'
    matched = []
    for c in ['reef_group_size','reef_group_size_evidence_ids','reef_spawning_mode','reef_spawning_mode_evidence_ids',
              'reef_multihabitat','reef_multihabitat_evidence_ids','reef_rafting','reef_rafting_evidence_ids']:
        functional[c] = ''
    fields = [('depth_max','reef_depth_max','m'), ('bodysize_max','reef_body_size_max','cm; length type not specified'),
              ('rafter','reef_rafting','binary source classification'), ('multihabitat','reef_multihabitat','binary source classification'),
              ('diet','reef_diet_guild','category'), ('groupsize','reef_group_size','category'),
              ('spawning','reef_spawning_mode','category')]
    for tax in crosswalk.to_dict('records'):
        if tax['attach_traits'] != '1':
            continue
        names = {tax['species'], tax['fishbase_name']}
        rows = reef[reef.match_name.isin(names)]
        require(len(rows) <= 1, 'Multiple reef matches need review')
        if rows.empty:
            continue
        r = rows.iloc[0]
        sp = tax['species']
        matched.append(dict(species=sp, source_species=r['species'], taxon_match=tax['match_status'],
                            **{k:v for k,v in r.to_dict().items() if k!='species'}))
        for field, trait, unit in fields:
            raw = val(r[field]).strip()
            if raw in {'','NA','N/A'}:
                continue
            normalized = raw
            if field in ['diet','groupsize','spawning']:
                mapping = {'diet':GUILDS,'groupsize':SOCIAL,'spawning':SPAWN}[field]
                require(raw in mapping, f'Unknown reef {field} code: {raw}')
                normalized = mapping[raw]
            if field in ['rafter','multihabitat']:
                require(float(raw) in {0,1}, 'Unknown reef binary code')
            flags, decision = [], 'include_contextual'
            if field == 'rafter':
                flags.append('often_genus_level_classification_not_direct_species_observation')
            if field == 'bodysize_max':
                flags.append('length_type_unspecified')
                previous = base.loc[base.species == sp, 'maximum_length_male_unsexed_cm'].iloc[0]
                if previous and (float(raw) <= 0 or max(float(raw)/float(previous),float(previous)/float(raw)) > 5):
                    flags.append('large_disagreement_with_FishBase_size_review_required')
                    decision = 'hold'
            if field == 'spawning' and sp == 'Syngnathus fuscus':
                flags.append('source_live_category_must_not_replace_brooding_or_egg_traits')
            key = f'REEF|{sp}|{field}'
            db.add(key, sp, trait, normalized, 'ATLANTIC_REEF_V2',
                f'traits&distributions, Excel row {r.excel_row}; {field}', source_taxon=r.match_name,
                unit=unit, evidence_type='compiled_trait_classification',
                reference_scope='dataset-level attribution; original per-cell study not supplied',
                upstream_citation='Dataset combines FishBase, Smithsonian and publications; per-cell upstream source unavailable',
                definition='Source codes expanded using archived data dictionary; no additional ecological inference.',
                context_json=dump({**r.to_dict(), 'raw_value':raw, 'project_taxon_match':tax['match_status']}),
                qc_flags='; '.join(flags), decision=decision, mapping_rule='Atlantic reef v2 codebook')
            if field == 'diet':
                ix = trophic.index[trophic.species == sp][0]
                trophic.loc[ix,['reef_diet_guild','reef_diet_guild_evidence_ids']] = [normalized,key]
                broad = trophic.loc[ix,'fishbase_feeding_group']
                comparison = 'different resolutions; preserve both sources'
                if broad == 'plants/detritus and animals' and raw in {'gc','mi','is'} or broad == 'mainly plants/detritus' and raw in {'gc','mi','is'}:
                    comparison = 'potential diet/ontogeny discrepancy; review before collapsing groups'
                trophic.loc[ix,'source_comparison'] = comparison
                db.link('trophic_traits', sp, trait, [key])
            elif field in ['groupsize','spawning','multihabitat','rafter']:
                ix = functional.index[functional.species == sp][0]
                functional.loc[ix,[trait,trait+'_evidence_ids']] = [normalized,key]
                db.link('functional_traits', sp, trait, [key])
    return pd.DataFrame(matched),source_issues


def import_curated(db, base, tables, trophic, iucn):
    rows = read_json(ROOT / 'config/species_traits_curated_evidence.json')
    for r in rows:
        require(r['species'] in set(base.species), 'Curated species outside roster')
        require(r['source_taxon'] == r['species'], 'New taxon transfer requires review')
        require('withheld' not in base.set_index('species').loc[r['species'],'taxon_match_status'], 'Withheld taxon')
        if r['source_id'] == 'FB_species':
            sr = tables['species']
            sr = sr[sr.Genus + ' ' + sr.Species == r['source_taxon']].iloc[0]
            require('5.8 cm' in sr.Comments and '47377' in sr.Comments, 'Curated source text changed')
        db.add(r['evidence_id'], r['species'], r['trait'], r['value'], r['source_id'],r['locator'],
            source_taxon=r['source_taxon'], unit=r['unit'], evidence_type=r['evidence_type'],
            reference_scope='curated passage; primary studies not inspected', upstream_citation=r['upstream_citation'],
            definition=r['definition'], context_json=dump(r), qc_flags=r['qc_flags'],
            decision=r['decision'],review_status=r['review_status'],
            value_numeric=r.get('value_numeric',''), value_min=r.get('value_min',''),value_max=r.get('value_max',''))
        if r['trait'] == 'diet_guild_contextual':
            ix = trophic.index[trophic.species == r['species']][0]
            trophic.loc[ix,['contextual_diet_guild','contextual_diet_guild_evidence_ids']] = [r['value'],r['evidence_id']]
            if r.get('comparison_note'):
                trophic.loc[ix,'source_comparison']=r['comparison_note']
            db.link('trophic_traits', r['species'], 'contextual_diet_guild', [r['evidence_id']])
        if r['trait'] == 'iucn_assessment_category':
            ix = iucn.index[iucn.species == r['species']][0]
            require(iucn.loc[ix,'assessment_id'] == r['assessment_id'], 'IUCN assessment mismatch')
            require(iucn.loc[ix,'iucn_category_reported'] == r['value'], 'Conflicting IUCN category requires review')
            require(iucn.loc[ix,'assessment_date'] == r['assessment_date'], 'IUCN assessment date mismatch')
            iucn.loc[ix,'assessment_review_evidence_ids'] = r['evidence_id']
            for field in ['iucn_category_reported','assessment_date','assessment_scope','criteria']:
                db.link('iucn_status',r['species'],field,[r['evidence_id']])
    return pd.DataFrame(rows)


# Connections to the proposal's response mechanisms; not claims of causal effects.
AXES = {
    'generation_time_model_years': ('life_history','generation_time_model','years','Growth-derived model; correlated with K; not observed generation length'),
    'maximum_age_wild_years': ('life_history','maximum_age_wild','years','Reported maximum age, source population context applies'),
    'maturity_age_reported_years_min': ('life_history','maturity_age_reported','years','Minimum across retained source records, not a confidence bound or global minimum'),
    'maturity_age_reported_years_max': ('life_history','maturity_age_reported','years','Maximum across retained source records; populations and sexes remain in evidence'),
    'growth_k_reported_per_year_min': ('life_history','growth_k_reported','1/year','Minimum across source growth estimates; not a confidence bound'),
    'growth_k_reported_per_year_max': ('life_history','growth_k_reported','1/year','Maximum across source growth estimates; not a confidence bound'),
    'maximum_length_male_unsexed_cm': ('size','maximum_length_male_unsexed','cm','Retain accompanying TL/SL/FL length type; no automatic conversion'),
    'depth_shallow_m': ('habitat','depth_shallow','m','Reported distribution boundary, not physiological tolerance'),
    'depth_deep_m': ('habitat','depth_deep','m','Reported distribution boundary, not physiological tolerance'),
    'water_column_habitat': ('habitat','water_column_habitat','category','Vertical habitat position'),
    'sexual_system': ('reproduction','ReproMode','category','Sexual system; retain database/source definitions'),
    'fertilization': ('reproduction','Fertilization','category','Fertilization mode'),
    'parental_care': ('reproduction','ParentalCare','category','Reported parental care category'),
    'spawning_pattern': ('reproduction','Spawning','category','Reported spawning pattern'),
    'larval_development_place': ('dispersal','PlaceofDevelopment','category','Developmental habitat, not a duration or dispersal distance'),
}


def existing_axes(db, base, functional):
    for field, (domain, trait, unit, definition) in AXES.items():
        functional[field] = base[field]
        functional[field+'_evidence_ids'] = ''
        for ix, row in base.iterrows():
            if not row[field]:
                continue
            keys = [k for k,e in db.evidence.items() if e['species'] == row.species and e['trait'] == trait and e['decision'] != 'hold']
            require(bool(keys), 'Existing summary lacks evidence: '+row.species+' '+field)
            functional.loc[ix,field+'_evidence_ids'] = '; '.join(keys)
            db.link('functional_traits', row.species, field, keys)
    functional['maximum_length_type'] = base.maximum_length_male_unsexed_type
    sup = csv(ROOT / 'Output/LifeHistorySupplement/life_history_80_species_supplemented.csv')
    require(list(sup.species) == list(base.species), 'Supplement species order changed')
    for field in ['migration_best_available','migration_best_available_basis','migration_scope']:
        functional[field] = sup[field]
    functional['migration_evidence_ids'] = sup.migration_best_available_evidence_ids
    for row in sup.to_dict('records'):
        if row['migration_best_available']:
            db.link('functional_traits',row['species'],'migration_best_available',row['migration_best_available_evidence_ids'].split('; '))


def contextual_profiles(db, base):
    """Expose regional literature estimates without pooling populations or methods."""
    selected=[e for e in db.evidence.values() if (e['evidence_id'].startswith('CUR') or e['evidence_id'].startswith('LHS'))
              and e['decision']=='include_contextual' and e['trait'] not in {'migration','iucn_assessment_category','population_trend_assessment'}]
    traits=sorted({e['trait'] for e in selected})
    rows=[]
    for sp in base.species:
        record={'species':sp}
        for trait in traits:
            found=[e for e in selected if e['species']==sp and e['trait']==trait]
            values=[]
            for e in found:
                ctx=json.loads(e['context_json'])
                values.append(dict(value=e['value'],unit=e['unit'],population=ctx.get('population','not specified'),
                                   sex=ctx.get('sex','not specified'),life_stage=ctx.get('life_stage','not specified'),
                                   evidence_id=e['evidence_id']))
            record[trait]=dump(values) if values else ''
            record[trait+'_evidence_ids']='; '.join(e['evidence_id'] for e in found)
            db.link('contextual_traits',sp,trait,[e['evidence_id'] for e in found])
        rows.append(record)
    return pd.DataFrame(rows)


def reference_bibliography(db, tables):
    refs=tables['refrens'].set_index('RefNo')
    selected=set()
    for e in db.evidence.values():
        match=re.fullmatch(r'FishBase reference (\d+)',e['upstream_citation'])
        if not match:
            continue
        number=int(match.group(1))
        if number not in refs.index:
            e['qc_flags']='; '.join(filter(None,[e['qc_flags'],'upstream_bibliographic_record_missing']))
            e['upstream_citation']+=' (bibliographic record absent from pinned reference table)'
            # The FishBase record remains attributable; do not invent a primary citation.
            continue
        selected.add(number)
        row=refs.loc[number]
        require(isinstance(row,pd.Series),'Duplicate reference record')
        citation=' '.join(val(row.get(c)) for c in ['Author','Year','Title','Source'] if present(row.get(c)))
        e['upstream_citation']=citation
        e['upstream_url']=f'https://www.fishbase.se/references/FBRefSummary.php?ID={number}'
    out=refs.loc[sorted(selected)].reset_index()
    keep=[c for c in ['RefNo','Author','Year','Title','Source','DOI','PaperURL'] if c in out]
    out=out[keep].fillna('')
    out['PaperURL_raw_json']=''
    out['bibliography_qc_flag']=''
    for ix,url in out.PaperURL.items():
        if re.search(r'[^\x09\x0a\x0d\x20-\ud7ff\ue000-\ufffd\U00010000-\U0010ffff]',str(url)):
            out.loc[ix,'PaperURL_raw_json']=json.dumps(url,ensure_ascii=True)
            out.loc[ix,'PaperURL']=''
            out.loc[ix,'bibliography_qc_flag']='malformed source URL; raw value retained as escaped JSON'
    return out


DOMAINS = {
 'generation_time': ['generation_time_model','generation_length_assessment'],
 'longevity': ['maximum_age_wild','maximum_age_captive','maximum_age_growth_record','maximum_observed_age','maximum_age_contextual'],
 'maturity_age': ['maturity_age_reported','maturity_age_growth_record','maturity_age_contextual','maturity_age_model'],
 'maturity_size': ['maturity_length_reported','maturity_length_source_min','maturity_length_source_second','maturity_length_contextual'],
 'growth': ['growth_k_reported','growth_k_keyfacts'],
 'fecundity': ['FecundityMin','FecundityMax','FecundityMean'],
 'larval_duration': ['LarvalDurationMin','LarvalDurationMax','LarvalDurationMod','larval_duration_reported'],
 'migration': ['migration'], 'diel_movement': ['diel_habitat_movement','diel_vertical_migration'],
 'body_size': ['maximum_length_male_unsexed','maximum_length_female','reef_body_size_max'],
 'body_shape': ['body_shape'], 'depth': ['depth_shallow','depth_deep','reef_depth_max'],
 'water_column': ['water_column_habitat'], 'sexual_system': ['ReproMode'],
 'parental_care': ['ParentalCare'], 'reproductive_guild': ['RepGuild1','RepGuild2'],
 'spawning': ['Spawning','reef_spawning_mode','spawning_aggregation','spawning_aggregation_reported','batch_spawning_reported'],
 'egg_traits': ['egg_buoyancy'], 'larval_habitat': ['PlaceofDevelopment'],
 'trophic_level': ['DietTroph','FoodTroph'],
 'trophic_group': ['fishbase_feeding_group','reef_diet_guild','diet_guild_contextual'],
 'feeding_mechanism': ['feeding_mechanism','FeedingType','feeding_type'],
 'sociality': ['schooling_reported','reef_group_size'],
 'activity': ['activity_reported'], 'mating_system': ['mating_system'],
 'habitat_breadth': ['reef_multihabitat'], 'rafting': ['reef_rafting'],
 'territoriality': ['adult_territoriality'], 'estuarine_use': ['estuarine_use'],
}


def gaps_and_dictionary(db, base):
    rows=[]
    field_rows=[]
    all_traits=sorted({e['trait'] for e in db.evidence.values()}|{t for values in DOMAINS.values() for t in values})
    for sp in base.species:
        ev=[e for e in db.evidence.values() if e['species']==sp]
        for domain, traits in DOMAINS.items():
            found=[e for e in ev if e['trait'] in traits]
            usable=[e for e in found if e['decision']!='hold']
            nonmodel=[e for e in usable if e['evidence_type'] not in {'model_or_derived_keyfacts'}]
            status='available_contextual' if nonmodel else 'model_only' if usable else 'held_only' if found else 'missing'
            rows.append(dict(species=sp,trait_domain=domain,coverage_status=status,
                evidence_ids='; '.join(e['evidence_id'] for e in found),
                note='Availability is not independent verification; scope, methods and quality flags remain mandatory.'))
        for trait in all_traits:
            found=[e for e in ev if e['trait']==trait]
            usable=[e for e in found if e['decision']!='hold']
            nonmodel=[e for e in usable if e['evidence_type']!='model_or_derived_keyfacts']
            state='available_contextual' if nonmodel else 'model_only' if usable else 'held_only' if found else 'missing'
            field_rows.append(dict(species=sp,trait=trait,coverage_status=state,
                evidence_ids='; '.join(e['evidence_id'] for e in found)))
    definitions=[dict(field=f,domain=d,source_trait=t,unit=u,interpretation=n) for f,(d,t,u,n) in AXES.items()]
    definitions += [dict(field=k,domain=k,source_trait='; '.join(v),unit='see evidence records',
                       interpretation='Gap-audit domain; source-specific measurements are not automatically interchangeable.') for k,v in DOMAINS.items()]
    return pd.DataFrame(rows),pd.DataFrame(definitions),pd.DataFrame(field_rows)


def write_sqlite(path, tables):
    """Create real keys/foreign keys, not just unrelated spreadsheet dumps."""
    temp = path.with_suffix('.tmp.sqlite')
    if temp.exists():
        raise ValueError('Temporary database already exists; inspect before rebuilding: '+str(temp))
    connection=sqlite3.connect(temp)
    try:
        connection.execute('PRAGMA foreign_keys=ON')
        for name,frame in tables.items():
            columns=list(frame.columns)
            real_columns = {'value_numeric','value_min','value_max','trophic_level_preferred',
                'trophic_level_diet','trophic_level_diet_se','trophic_level_food_items',
                'trophic_level_food_items_se','trophic_level_se'}
            specs=['"'+c+'" '+('REAL' if c in real_columns else 'TEXT') for c in columns]
            primary={'species':'species','sources':'source_id','trait_evidence':'evidence_id',
                     'iucn_status':'species','trophic_traits':'species','functional_traits':'species'}.get(name)
            if primary:
                specs.append('PRIMARY KEY ("'+primary+'")')
            if 'species' in columns and name!='species':
                specs.append('FOREIGN KEY (species) REFERENCES species(species)')
            if name=='trait_evidence':
                specs.append('FOREIGN KEY (source_id) REFERENCES sources(source_id)')
            if name=='summary_evidence':
                specs.append('FOREIGN KEY (evidence_id) REFERENCES trait_evidence(evidence_id)')
                specs.append('PRIMARY KEY (summary_table,species,field,evidence_id)')
            if name=='trait_gaps':
                specs.append('PRIMARY KEY (species,trait_domain)')
            connection.execute('CREATE TABLE "'+name+'" ('+','.join(specs)+')')
            sql='INSERT INTO "'+name+'" VALUES ('+','.join('?' for _ in columns)+')'
            connection.executemany(sql,[tuple(None if not present(x) or x=='' else str(x) for x in row)
                                       for row in frame.itertuples(index=False,name=None)])
        connection.execute('CREATE INDEX evidence_species_trait ON trait_evidence(species,trait)')
        connection.execute('CREATE VIEW trait_provenance AS SELECT e.*, s.citation, s.url, s.version, s.sha256, s.retrieved_at FROM trait_evidence e JOIN sources s USING(source_id)')
        require(not connection.execute('PRAGMA foreign_key_check').fetchall(),'Database foreign key violation')
        require(connection.execute('PRAGMA integrity_check').fetchone()[0]=='ok','Database integrity failure')
        connection.commit()
    finally:
        connection.close()
    temp.replace(path)


def excel_frame(frame, table, changes):
    """Excel cannot store some source control characters or very long cells.

    Escape only the convenience export; canonical CSV/SQLite remain lossless.
    """
    result=frame.copy()
    for column in frame:
        for index,value in frame[column].items():
            if not isinstance(value,str):
                continue
            safe=re.sub(r'[^\x09\x0a\x0d\x20-\ud7ff\ue000-\ufffd\U00010000-\U0010ffff]',
                        lambda m:f'\\u{ord(m[0]):04x}',value)
            reasons=[]
            if safe!=value:
                reasons.append('control characters visibly escaped')
            if len(safe)>32767:
                safe=safe[:32600]+' [Excel display truncated; complete value in CSV/SQLite]'
                reasons.append('Excel cell length limit')
            if reasons:
                changes.append(dict(table=table,csv_row=int(index)+2,column=column,reason='; '.join(reasons)))
                result.at[index,column]=safe
    return result


def build(out=None):
    out=Path(out) if out else ROOT/'Output/SpeciesTraits'
    db=Database()
    base,crosswalk,tables,policy=load_inputs(db)
    old=import_previous(db,base)
    iucn,trophic,functional=enrich_fishbase(db,base,crosswalk,tables)
    reef,source_issues=enrich_reef(db,crosswalk,trophic,functional,base)
    curated=import_curated(db,base,tables,trophic,iucn)
    existing_axes(db,base,functional)
    contextual=contextual_profiles(db,base)
    references=reference_bibliography(db,tables)
    gap,dictionary,field_gaps=gaps_and_dictionary(db,base)
    species=crosswalk.copy()
    sources=pd.DataFrame(db.sources.values()).fillna('')
    evidence=pd.DataFrame(db.evidence.values()).fillna('')
    require(evidence.evidence_id.is_unique,'Duplicate evidence')
    for c in ['species','source_taxon','trait','value','source_id','locator','unit','evidence_type','reference_scope']:
        require((evidence[c]!='').all(),'Missing evidence attribution: '+c)
    links=pd.DataFrame(db.links).drop_duplicates()
    summary=base.merge(iucn,on='species',validate='one_to_one',suffixes=('','_iucn'))
    summary=summary.merge(trophic,on='species',validate='one_to_one')
    # Append new functional fields only; original columns already remain in summary.
    summary=summary.merge(functional[[c for c in functional if c=='species' or c not in summary]],on='species',validate='one_to_one')
    require(summary[base.columns].equals(base),'Original values changed')
    coverage=dict(species=80,fishbase_version=VERSION,
        redlist_categories_reported=int((iucn.iucn_category_reported!='').sum()),
        redlist_category_counts=iucn.loc[iucn.iucn_category_reported!='','iucn_category_reported'].value_counts().to_dict(),
        redlist_fishbase_ne_unverified=int((iucn.iucn_raw_code=='N.E.').sum()),
        redlist_taxon_unresolved=int((iucn.verification=='taxon unresolved').sum()),
        redlist_current_latest_verified=0, iucn_public_narrative_species=1,
        trophic_level_species=int((trophic.trophic_level_preferred!='').sum()),
        trophic_diet_estimates=int((trophic.trophic_level_diet!='').sum()),
        trophic_food_estimates=int((trophic.trophic_level_food_items!='').sum()),
        fishbase_feeding_group_species=int((trophic.fishbase_feeding_group!='').sum()),
        reef_matched_species=len(reef), reef_diet_guild_species=int((trophic.reef_diet_guild!='').sum()),
        any_trophic_group_species=int(((trophic.fishbase_feeding_group!='')|(trophic.reef_diet_guild!='')|(trophic.contextual_diet_guild!='')).sum()),
        body_shape_species=int((functional.body_shape!='').sum()),
        curated_new_evidence_records=len(curated), total_evidence_records=len(evidence),
        gap_audit_rows=len(gap),field_gap_audit_rows=len(field_gaps),independent_review='pending',
        limitation='Red List values are attributed snapshots, not a live/current global-status audit. No API token was available.')
    database_tables={'species':species,'sources':sources,'trait_evidence':evidence,
        'iucn_status':iucn,'trophic_traits':trophic,'functional_traits':functional,
        'summary_evidence':links,'trait_gaps':gap,'trait_dictionary':dictionary,
        'contextual_traits':contextual,'references':references,
        'source_issues':source_issues,
        'trait_field_gaps':field_gaps,
        'reef_match_records':reef,'curated_evidence':curated,'species_summary':summary}
    out.mkdir(parents=True,exist_ok=True)
    for name,frame in database_tables.items():
        frame.to_csv(out/(name+'.csv'),index=False,lineterminator='\n')
    # Self-contained per-characterization provenance for reports and review.
    provenance=evidence.merge(sources[['source_id','citation','url','version','sha256','retrieved_at','archive_path']],
                              on='source_id',validate='many_to_one')
    provenance.to_csv(out/'trait_provenance.csv',index=False,lineterminator='\n')
    write_sqlite(out/'species_traits.sqlite',database_tables)
    notes=pd.DataFrame([
        ('Scope','80 frozen species; original FishBase values unchanged; subspecies pooling retained.'),
        ('IUCN','72 source-reported categories, not live verification. FishBase N.E. and unmatched taxa remain distinct; no regional/global substitution.'),
        ('Trophic levels','Diet-composition estimate preferred; food-item estimate fallback. Both methods/SEs/context retained. These are estimated, not direct measurements.'),
        ('Trophic groups','FishBase broad feeding class and reef diet guild remain separate. Source disagreement and ontogenetic changes require review.'),
        ('Functional traits','Source-attributed trait profiles, not functional-diversity scores. Body size retains length type. Reef rafting is often inferred at genus level.'),
        ('IUCN narrative','Substantial public indexed assessment text is archived and explicitly labeled; not an API response or complete PDF. Primary-study and independent review pending.'),
        ('Evidence','trait_provenance provides citations, locators, reference scope and hashes. summary_evidence links summary fields to records.'),
        ('Missingness','trait_gaps covers all trait domains. Missing is not zero/absence. Model-only and held-only coverage are separate.'),
        ('Reproduce','python3 Scripts/build_species_traits.py; see docs/life_history_workflow.md'),
    ],columns=['item','description'])
    excel_changes=[]
    with pd.ExcelWriter(out/'species_traits_80.xlsx',engine='openpyxl') as writer:
        notes.to_excel(writer,sheet_name='README',index=False)
        for name in ['species_summary','iucn_status','trophic_traits','functional_traits','contextual_traits',
                     'trait_gaps','trait_field_gaps','curated_evidence','reef_match_records','source_issues',
                     'sources','references','summary_evidence','trait_dictionary']:
            excel_frame(database_tables[name],name,excel_changes).to_excel(writer,sheet_name=name,index=False)
        excel_frame(provenance,'trait_provenance',excel_changes).to_excel(writer,sheet_name='trait_provenance',index=False)
        pd.DataFrame(excel_changes,columns=['table','csv_row','column','reason']).to_excel(writer,sheet_name='excel_export_notes',index=False)
        for ws in writer.book.worksheets:
            ws.freeze_panes='B2';ws.auto_filter.ref=ws.dimensions
            for col in ws.columns:
                ws.column_dimensions[col[0].column_letter].width=min(60,max(18,len(str(col[0].value))+2))
    pd.DataFrame(excel_changes,columns=['table','csv_row','column','reason']).to_csv(out/'excel_export_notes.csv',index=False)
    (out/'coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')
    files=[ROOT/'Scripts/build_species_traits.py',ROOT/'Scripts/download_species_traits.py',
           ROOT/'requirements-life-history.txt',RAW/'download_manifest.json']
    files+=sorted((ROOT/'config').glob('species_traits_*.json'))
    files+=sorted((ROOT/'Data/SpeciesTraits/searches').glob('*.json'))
    files += [ROOT/'Output/LifeHistory/life_history_80_species.csv',ROOT/'Output/LifeHistory/taxon_crosswalk.csv',
              ROOT/'Output/LifeHistory/trait_evidence.csv',ROOT/'Output/LifeHistorySupplement/build_manifest.json',
              ROOT/'Output/LifeHistorySupplement/trait_evidence.csv',ROOT/'Output/LifeHistorySupplement/sources.csv',
              ROOT/'Output/LifeHistorySupplement/life_history_80_species_supplemented.csv',
              ROOT/'config/life_history_taxon_crosswalk.csv']
    files += [ROOT/s['archive_path'] for s in db.sources.values()]
    files += sorted((ROOT/'Data/SpeciesTraits/sources').glob('*.metadata.json'))
    outputs=[p for p in out.iterdir() if p.is_file() and p.name!='build_manifest.json']
    manifest=dict(schema_version=policy['schema_version'],command='python3 Scripts/build_species_traits.py',
        python=platform.python_version(),pandas=pd.__version__,openpyxl=openpyxl.__version__,
        sqlite=sqlite3.sqlite_version,
        inputs={str(p.relative_to(ROOT)):sha(p) for p in sorted(set(files))},
        outputs={p.name:sha(p) for p in sorted(outputs)},
        notes='CSV tables are canonical; SQLite NULL represents missing cells; Excel zip timestamps may vary. Independent review pending.')
    (out/'build_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return coverage


if __name__=='__main__':
    print(json.dumps(build(),indent=2))
