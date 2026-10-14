#!/usr/bin/env python3
"""Cache GEOME and publication-linked metadata; never download genomic read files."""
import argparse
import csv
import gzip
import json
import io
import zipfile
import xml.etree.ElementTree as ET
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import genomics_archive_io as archive

ROOT = archive.ROOT
DEST = ROOT / 'Data/Genomics/location_sources'


def collect_geome(online):
    taxa = archive.rows(ROOT / 'Data/Genomics/normalized/taxa.csv')
    def one(t):
        names = sorted({t['species'], t['archive_name']} - {''})
        # Do not borrow another species' data for the unresolved historical name.
        query = '(' + ' OR '.join('scientificName="' + n + '"' for n in names) + ') _select_:[Event,Tissue]'
        page, records, seen = 0, [], set()
        while True:
            url = archive.endpoint('https://api.geome-db.org/records/Sample/json', q=query, limit=1000, page=page)
            payload = archive.fetch(url, 'geome', online)
            if payload.startswith(b'\x1f\x8b'):
                payload = gzip.decompress(payload)  # GEOME sends gzip even without Accept-Encoding
            j = json.loads(payload)
            content = j.get('content') or {}
            batch = content.get('Sample', [])
            def key(r, field):
                return (r.get('projectId',''), r.get('expeditionCode',''), r.get(field,''))
            events = {key(r,'eventID'):r for r in content.get('Event', [])}
            tissues = {}
            for r in content.get('Tissue', []):
                tissues.setdefault(key(r,'materialSampleID'), []).append(r)
            for s in batch:
                bcid = s.get('bcid', '')
                if bcid in seen:
                    raise ValueError('Repeated GEOME page/record: ' + bcid)
                seen.add(bcid)
                e = events.get(key(s,'eventID'), {})
                ts = tissues.get(key(s,'materialSampleID'), [])
                ids = sorted(set(re.findall(r'\bSAM[NED][A-Z]?\d+\b', ' '.join(str(v) for r in [s]+ts for k,v in r.items() if 'accession' in k.lower() or k=='associatedSequences'))))
                def get(*keys):
                    return ' | '.join(dict.fromkeys(str(r[k]) for r in [e,s]+ts for k in keys if r.get(k)))
                records.append(dict(species=t['species'], archive_name=t['archive_name'], geome_bcid=bcid,
                    project_id=s.get('projectId',''), expedition=s.get('expeditionCode',''),
                    material_sample_id=s.get('materialSampleID',''), scientific_name=s.get('scientificName',''),
                    biosample_accessions=' | '.join(ids), latitude=get('decimalLatitude'), longitude=get('decimalLongitude'),
                    year=get('yearCollected'), month=get('monthCollected'), day=get('dayCollected'),
                    event_date=get('eventDate'), locality=get('country','stateProvince','locality','verbatimLocality'),
                    coordinate_uncertainty_m=get('coordinateUncertaintyInMeters'), geodetic_datum=get('geodeticDatum'),
                    voucher=get('voucherCatalogNumber'), associated_sequences=get('associatedSequences'),
                    associated_references=get('associatedReferences','references'),
                    source_url='https://n2t.net/' + bcid, query_url=url))
            if not batch or len(batch) < int(j.get('limit',1000)):
                break
            page += 1
        print(f'GEOME {t["species"]}: {len(records)} samples', flush=True)
        return records, dict(species=t['species'], query=query, status='complete', sample_records=len(records), pages=page+1, error='')
    records, logs = [], []
    with ThreadPoolExecutor(max_workers=3) as ex:
        tasks = [(t,ex.submit(one,t)) for t in taxa]
        for t, fut in tasks:
            try:
                r,log=fut.result();records.extend(r);logs.append(log)
            except Exception as err:
                logs.append(dict(species=t['species'],query='',status='failed',sample_records='',pages='',error=str(err)))
    archive.write_csv(DEST / 'geome_records.csv', records)
    archive.write_csv(DEST / 'geome_searches.csv',logs)
    if any(r['status'] != 'complete' for r in logs):
        raise RuntimeError('GEOME search incomplete; see geome_searches.csv. Completed inventory not replaced.')


def download_sources(online):
    sources=json.loads((ROOT/'config/genomics_location_sources.json').read_text())
    manifest=[]
    for source in sources:
        data=archive.fetch(source['url'],'location_publications',online)
        # Named copies make the original evidence easy for a reviewer to inspect.
        (DEST/source['file']).write_bytes(data)
        meta=next(r for r in reversed(archive.LOG) if r['url']==source['url'])
        manifest.append(dict(**source,source_sha256=meta['sha256'],retrieved_utc=meta['retrieved_utc']))
    archive.write_csv(DEST/'source_manifest.csv',manifest)


def xlsx_sheet(data, sheet_name):
    """Transport cached spreadsheet values to CSV without an Excel/R dependency."""
    z=zipfile.ZipFile(io.BytesIO(data)); ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    shared=[]
    if 'xl/sharedStrings.xml' in z.namelist():
        shared=[''.join(x.itertext()) for x in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)]
    book=ET.fromstring(z.read('xl/workbook.xml'))
    rels={r.attrib['Id']:r.attrib['Target'] for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
    sheet=next(s for s in book.findall('m:sheets/m:sheet',ns) if s.attrib['name']==sheet_name)
    target=rels[sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
    path=target.lstrip('/') if target.startswith('/') else 'xl/'+target
    result=[]
    for row in ET.fromstring(z.read(path)).findall('m:sheetData/m:row',ns):
        values=[]
        for c in row.findall('m:c',ns):
            col=0
            for letter in re.match('[A-Z]+',c.attrib['r']).group(): col=col*26+ord(letter)-64
            while len(values)<col:values.append('')
            v=c.find('m:v',ns);value=v.text if v is not None and v.text else ''
            if c.get('t')=='s':value=shared[int(value)]
            elif c.get('t')=='inlineStr':value=''.join(c.find('m:is',ns).itertext())
            values[col-1]=value
        result.append((int(row.attrib['r']),values))
    return result


def extract_tables():
    specs=[('fundulus_evad123_supp.zip','evad123_supplementary_data.zip','Drown_Trans-acting_Drivers_SupplementalTables2023_GBE.xlsx', ['Table_S3']),
           ('atherino_evac111_supp.zip','evac111_supplementary_data.zip','Hardhead_Supplementary_Tables_revised.xlsx',['TableS3','TableS4'])]
    for outer,inner,workbook,sheets in specs:
        oz=zipfile.ZipFile(DEST/outer);iz=zipfile.ZipFile(io.BytesIO(oz.read(inner)))
        data=iz.read(workbook)
        for sheet in sheets:
            rr=xlsx_sheet(data,sheet);header=next(v for n,v in rr if n==2)
            out=[]
            for rownum,values in rr:
                if rownum<=2 or not any(values):continue
                padded=values+['']*max(0,len(header)-len(values))
                row=dict(zip(header,padded));row['source_row']=rownum;row['source_member']=inner+'/'+workbook+'#'+sheet
                out.append(row)
            archive.write_csv(DEST/(outer.split('_supp')[0]+'_'+sheet+'.csv'),out)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--download',action='store_true');p.add_argument('--geome-only',action='store_true');p.add_argument('--sources-only',action='store_true')
    args=p.parse_args();DEST.mkdir(parents=True,exist_ok=True)
    if not args.sources_only: collect_geome(args.download)
    if not args.geome_only:
        download_sources(args.download)
        extract_tables()
    # Reconstruct index from cache manifests so partial runs do not lose prior request provenance.
    logs=[]
    for kind in ['geome','location_publications']:
        for f in sorted((archive.RAW/kind).glob('*.json')):logs.append(json.loads(f.read_text()))
    archive.write_csv(DEST/'queries.csv',logs)
