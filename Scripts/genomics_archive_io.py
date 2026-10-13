#!/usr/bin/env python3
"""Metadata transport and SQLite export. Scientific decisions live in R.
Uses only Python 3 standard library; reads no sequencing files.
"""
import argparse
import csv
import gzip
import hashlib
import io
import json
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'Data/Genomics/raw'
NORM = ROOT / 'Data/Genomics/normalized'
FIELDS = ('run_accession,sample_accession,secondary_sample_accession,sample_alias,'
          'study_accession,secondary_study_accession,experiment_accession,scientific_name,tax_id,'
          'library_strategy,library_source,library_selection,library_layout,library_name,'
          'base_count,read_count,instrument_platform,instrument_model,collection_date,country,'
          'location,lat,lon,sample_title,sample_description,study_title,experiment_title,'
          'library_construction_protocol,isolate,bio_material,specimen_voucher,sex,dev_stage,'
          'tissue_type,isolation_source,first_public,last_updated,fastq_ftp,fastq_md5,sra_ftp')
NCBI_LOCK = threading.Lock()
NCBI_LAST = 0.0
LOG = []
LOG_LOCK = threading.Lock()


def rows(path):
    with open(path, encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write_csv(path, data, columns=None):
    columns = columns or list(dict.fromkeys(k for row in data for k in row))
    with open(path, 'w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=columns, extrasaction='ignore')
        w.writeheader()
        w.writerows(data)


def fetch(url, kind, online=False, refresh=False):
    """Cache exact response bytes compressed, including URL, timestamp and SHA256."""
    global NCBI_LAST
    key = hashlib.sha256(url.encode()).hexdigest()
    folder = RAW / kind
    folder.mkdir(parents=True, exist_ok=True)
    body_path, meta_path = folder / (key + '.gz'), folder / (key + '.json')
    if body_path.exists() and meta_path.exists() and not refresh:
        data = gzip.decompress(body_path.read_bytes())
        meta = json.loads(meta_path.read_text())
        if hashlib.sha256(data).hexdigest() != meta['sha256']:
            raise ValueError('Corrupt metadata cache: ' + str(body_path))
    else:
        if not online:
            raise RuntimeError('Metadata not cached; run with --download: ' + url)
        for attempt in range(5):
            try:
                if 'ncbi.nlm.nih.gov' in url:
                    with NCBI_LOCK:
                        time.sleep(max(0, 0.4 - (time.monotonic() - NCBI_LAST)))
                        NCBI_LAST = time.monotonic()
                req = urllib.request.Request(url, headers={'User-Agent': 'USFC-GP-genomics-inventory/1.0', 'Accept': '*/*'})
                with urllib.request.urlopen(req, timeout=180) as response:
                    data = response.read()
                    status = response.status
                break
            except (urllib.error.URLError, TimeoutError) as exc:
                if attempt == 4:
                    raise
                time.sleep(2 ** attempt)
        meta = dict(url=url, retrieved_utc=datetime.now(timezone.utc).isoformat(),
                    sha256=hashlib.sha256(data).hexdigest(), http_status=status,
                    bytes=len(data), cache_path=str(body_path.relative_to(ROOT)))
        body_path.write_bytes(gzip.compress(data, mtime=0))
        meta_path.write_text(json.dumps(meta, indent=2) + '\n')
    with LOG_LOCK:
        LOG.append(meta)
    return data


def endpoint(base, **params):
    return base + '?' + urllib.parse.urlencode(params)


def collect_species(row, online, refresh):
    sp = row['species']
    query = sp
    note = 'ENA any-name exact lookup; descendants included in archive searches'
    if sp == 'Coelorinchus carminatus':
        query = 'Coelorinchus caelorhincus carminatus'
        note = 'NCBI subspecies 1266865 only; parent-species proxy withheld for population records'
    elif sp == 'Helicolenus maderensis':
        query = 'Helicolenus dactylopterus'
        note = 'Goode & Bean authority-resolved synonym per project crosswalk; regional identity requires review'
    url = 'https://www.ebi.ac.uk/ena/taxonomy/rest/any-name/' + urllib.parse.quote(query)
    tx = dict(species=sp, query_name=query, taxonomy_url=url, tax_id='', archive_name='',
              rank='', taxonomy_status='unresolved', decision_basis=note,
              read_query_status='not_searched', assembly_query_status='not_searched')
    run_rows, assembly_rows, attrs = [], [], []
    taxa = json.loads(fetch(url, 'taxonomy', online, refresh))
    if sp == 'Myctophum opalinum':
        tx['taxonomy_status'] = 'ambiguous_name_withheld'
        tx['decision_basis'] = 'Project crosswalk withholds Myctophum affine synonym; no transfer or double counting'
    elif len(taxa) == 1:
        t = taxa[0]
        tx.update(tax_id=t['taxId'], archive_name=t['scientificName'], rank=t['rank'],
                  taxonomy_status='exact_name' if sp == t['scientificName'] else 'documented_name_mapping')
    else:
        tx['decision_basis'] += '; matched taxa: ' + '; '.join(t['scientificName'] for t in taxa)
    if tx['tax_id']:
        tid = tx['tax_id']
        read_url = endpoint('https://www.ebi.ac.uk/ena/portal/api/search', result='read_run',
                            query=f'tax_tree({tid}) AND (library_source="GENOMIC" OR library_strategy="WGS")',
                            fields=FIELDS, format='tsv', limit=0)
        data = fetch(read_url, 'runs', online, refresh).decode('utf-8-sig')
        if not data.startswith('run_accession\t'):
            raise ValueError(f'Unexpected ENA result for {sp}: {data[:200]}')
        run_rows = [dict(species=sp, **r) for r in csv.DictReader(io.StringIO(data), delimiter='\t')]
        tx.update(read_query_status='complete', read_query_url=read_url, genomic_runs_returned=len(run_rows))
        reports, page = [], ''
        while True:
            params = dict(page_size=1000)
            if page:
                params['page_token'] = page
            assembly_url = endpoint(f'https://api.ncbi.nlm.nih.gov/datasets/v2/genome/taxon/{tid}/dataset_report', **params)
            j = json.loads(fetch(assembly_url, 'assemblies', online, refresh))
            reports.extend(j.get('reports', []))
            page = j.get('next_page_token', '')
            if not page:
                if len(reports) != int(j.get('total_count', len(reports))):
                    raise ValueError('NCBI assembly pagination count mismatch: ' + sp)
                break
        tx.update(assembly_query_status='complete', assembly_records_returned=len(reports))
        for r in reports:
            a, ann, stats = r.get('assembly_info', {}), r.get('annotation_info', {}), r.get('assembly_stats', {})
            bio = a.get('biosample', {})
            paired = a.get('paired_assembly', {})
            rec = dict(species=sp, assembly_accession=r['accession'], current_accession=r.get('current_accession', ''),
                       source_database=r.get('source_database', ''), archive_name=r.get('organism', {}).get('organism_name', ''),
                       tax_id=r.get('organism', {}).get('tax_id', ''), sample_accession=bio.get('accession', ''),
                       study_accession=a.get('bioproject_accession', ''), assembly_level=a.get('assembly_level', ''),
                       assembly_status=a.get('assembly_status', ''), assembly_name=a.get('assembly_name', ''),
                       assembly_type=a.get('assembly_type', ''), diploid_role=a.get('diploid_role', ''),
                       paired_accession=paired.get('accession', ''), refseq_category=a.get('refseq_category', ''),
                       total_sequence_length=stats.get('total_sequence_length', ''),
                       contig_n50=stats.get('contig_n50', ''), scaffold_n50=stats.get('scaffold_n50', ''),
                       assembly_coverage_reported=stats.get('genome_coverage', ''),
                       assembly_release_date=a.get('release_date', ''), sequencing_tech=a.get('sequencing_tech', ''),
                       annotation_name=ann.get('name', ''), annotation_provider=ann.get('provider', ''),
                       annotation_release_date=ann.get('release_date', ''), annotation_status=ann.get('status', ''),
                       annotation_method=ann.get('method', ''), annotation_pipeline=ann.get('pipeline', ''),
                       gene_count=ann.get('stats', {}).get('gene_counts', {}).get('total', ''),
                       protein_coding_gene_count=ann.get('stats', {}).get('gene_counts', {}).get('protein_coding', ''),
                       source_url='https://www.ncbi.nlm.nih.gov/datasets/genome/' + r['accession'] + '/',
                       sample_title=bio.get('description', {}).get('title', ''))
            assembly_rows.append(rec)
            for attr in bio.get('attributes', []):
                attrs.append(dict(species=sp, sample_accession=bio.get('accession', ''),
                                  attribute=attr.get('name', ''), value=attr.get('value', ''),
                                  source='NCBI_Datasets_BioSample', source_url=rec['source_url']))
    print(f'{sp}: {tx["taxonomy_status"]}, {len(run_rows)} genomic runs, {len(assembly_rows)} assemblies', flush=True)
    return tx, run_rows, assembly_rows, attrs


def collect(online=False, refresh=False):
    NORM.mkdir(parents=True, exist_ok=True)
    roster = rows(ROOT / 'Output/SpeciesSelection/species_investigation_queue.csv')
    results, failures = [], []
    with ThreadPoolExecutor(max_workers=4) as ex:
        futures = [(r['species'], ex.submit(collect_species, r, online, refresh)) for r in roster]
        for sp, fut in futures:
            try:
                results.append(fut.result())
            except Exception as exc:
                failures.append(dict(species=sp, error=str(exc)))
    write_csv(NORM / 'acquisition_errors.csv', failures, ['species', 'error'])
    if failures:
        write_csv(NORM / 'queries.csv', LOG)
        raise RuntimeError(f'{len(failures)} species failed; see acquisition_errors.csv. Cached successes retained; rerun.')
    taxonomy = [r[0] for r in results]
    runs = [x for r in results for x in r[1]]
    assemblies = [x for r in results for x in r[2]]
    attrs = [x for r in results for x in r[3]]
    # Fetch full biological-sample attributes, including custom collection metadata.
    species_by_sample = {}
    for rec in runs + assemblies:
        sid = rec.get('sample_accession')
        if sid:
            species_by_sample.setdefault(sid, set()).add(rec['species'])
    samples = sorted(species_by_sample)
    batches = [samples[i:i+80] for i in range(0, len(samples), 80)]
    def sample_batch(batch):
        url = 'https://www.ebi.ac.uk/ena/browser/api/xml/' + ','.join(batch)
        tree = ET.fromstring(fetch(url, 'samples', online, refresh))
        out, found = [], set()
        for s in tree.iter('SAMPLE'):
            ids = {e.text for e in s.findall('./IDENTIFIERS/*') if e.text} | {s.get('accession', '')}
            matched = ids.intersection(batch)
            for sid in matched:
                found.add(sid)
                values = [('sample_title', s.findtext('TITLE', '')), ('sample_description', s.findtext('DESCRIPTION', ''))]
                values += [(v.findtext('TAG', ''), v.findtext('VALUE', '')) for v in s.findall('./SAMPLE_ATTRIBUTES/SAMPLE_ATTRIBUTE')]
                for sp in species_by_sample[sid]:
                    for key, value in values:
                        if value:
                            out.append(dict(species=sp, sample_accession=sid, attribute=key, value=value,
                                            source='ENA_sample_XML', source_url='https://www.ebi.ac.uk/ena/browser/view/' + sid))
        return out, found
    found = set()
    with ThreadPoolExecutor(max_workers=4) as ex:
        for i, (more, got) in enumerate(ex.map(sample_batch, batches)):
            attrs.extend(more)
            found.update(got)
            if i % 10 == 0:
                print(f'Sample metadata batches {i+1}/{len(batches)}', flush=True)
    # A missing XML record is not silently declared complete; tabular metadata remains available.
    status = [dict(species=sp, sample_accession=sid, xml_status='retrieved' if sid in found else 'not_returned')
              for sid in samples for sp in sorted(species_by_sample[sid])]
    study_ids = sorted({r.get('study_accession') or r.get('secondary_study_accession', '')
                        for r in runs + assemblies} - {''})
    studies = []
    # ENA requires homogeneous PROJECT vs STUDY accession types within each call.
    study_batches = []
    for project_type in (True, False):
        group = [sid for sid in study_ids if sid.startswith('PRJ') == project_type]
        study_batches.extend(group[i:i+40] for i in range(0, len(group), 40))
    for batch in study_batches:
        url = 'https://www.ebi.ac.uk/ena/browser/api/xml/' + ','.join(batch)
        tree = ET.fromstring(fetch(url, 'studies', online, refresh))
        for study in list(tree.iter('PROJECT')) + list(tree.iter('STUDY')):
            ids = {e.text for e in study.findall('./IDENTIFIERS/*') if e.text} | {study.get('accession', '')}
            for sid in sorted(ids.intersection(batch)):
                xrefs = ['%s:%s' % (x.findtext('DB', ''), x.findtext('ID', ''))
                         for x in study.findall('.//XREF_LINK') if x.findtext('DB', '').upper() in ('PUBMED', 'DOI')]
                studies.append(dict(study_accession=sid, study_title=study.findtext('TITLE') or study.findtext('.//STUDY_TITLE', ''),
                                    study_description=study.findtext('DESCRIPTION') or study.findtext('.//STUDY_ABSTRACT', ''),
                                    publication_references=' | '.join(xrefs),
                                    source_url='https://www.ebi.ac.uk/ena/browser/view/' + sid))
    write_csv(NORM / 'studies.csv', studies,
              ['study_accession','study_title','study_description','publication_references','source_url'])
    write_csv(NORM / 'taxa.csv', taxonomy)
    write_csv(NORM / 'runs.csv', runs, ['species'] + FIELDS.split(','))
    write_csv(NORM / 'assemblies.csv', assemblies)
    # Remove exact duplicate attributes returned in paired assembly records.
    attrs = list({tuple(sorted(r.items())): r for r in attrs}.values())
    write_csv(NORM / 'sample_attributes.csv', attrs, ['species','sample_accession','attribute','value','source','source_url'])
    write_csv(NORM / 'sample_retrieval.csv', status)
    write_csv(NORM / 'queries.csv', sorted({r['url']: r for r in LOG}.values(), key=lambda r:r['url']))
    print(f'Completed: {len(taxonomy)} species, {len(runs)} genomic runs, {len(assemblies)} assemblies, {len(samples)} sample accessions.', flush=True)


def export_sqlite():
    out = ROOT / 'Output/Genomics'
    temp = out / 'genomics.sqlite.tmp'
    if temp.exists():
        temp.unlink()
    con = sqlite3.connect(temp)
    for path in sorted(out.glob('*.csv')):
        records = rows(path)
        with open(path, encoding='utf-8-sig', newline='') as f:
            fields = next(csv.reader(f))
        # Preserve accession IDs and evidence strings; use explicit numeric affinity only.
        numeric = {'latitude','longitude','archive_latitude','archive_longitude','coordinate_uncertainty_m','cell_lon','cell_lat','nominal_depth','total_sequence_length','base_count','wgs_bases','short_read_wgs_bases'}
        integer = {'year','archive_year','year_start','year_end','wgs_runs','wgs_samples','assembly_records','annotated_assemblies','annotated_reference_assemblies','mapped_dated_samples','genomic_runs','gene_count','protein_coding_gene_count','raw_run_count','read_count','genomic_sample_count','cell_sample_count','run_count','sample_count','archive_coordinates','enriched_coordinates','newly_georeferenced','archive_localities','enriched_localities','archive_years','enriched_years','coordinate_conflicts','quality_exclusions','mapping_candidates','sample_records','pages'}
        types = {f: ('REAL' if f in numeric else 'INTEGER' if f in integer else 'TEXT') for f in fields}
        name = path.stem
        con.execute('CREATE TABLE "'+name+'" (' + ','.join('"'+f+'" '+types[f] for f in fields) + ')')
        con.executemany('INSERT INTO "'+name+'" VALUES ('+','.join('?' for _ in fields)+')',
                        [[r.get(f) or None for f in fields] for r in records])
        for key in ('species','sample_accession','run_accession','assembly_accession','study_accession','source_id','evidence_id'):
            if key in fields:
                con.execute(f'CREATE INDEX "{name}_{key}" ON "{name}" ("{key}")')
    con.execute('CREATE UNIQUE INDEX samples_key ON samples(species,sample_accession)')
    con.execute('CREATE UNIQUE INDEX runs_key ON runs(species,run_accession)')
    con.execute('CREATE UNIQUE INDEX assemblies_key ON assemblies(species,assembly_accession)')
    con.commit()
    assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    con.close()
    temp.replace(out / 'genomics.sqlite')
    print('Wrote Output/Genomics/genomics.sqlite')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download', action='store_true', help='Allow public metadata retrieval for cache misses')
    parser.add_argument('--refresh', action='store_true', help='Replace cached metadata; requires --download')
    parser.add_argument('--sqlite', action='store_true', help='Export completed R-generated CSV tables to SQLite, offline')
    args = parser.parse_args()
    if args.refresh and not args.download:
        parser.error('--refresh requires --download')
    if args.sqlite:
        export_sqlite()
    else:
        collect(args.download, args.refresh)
