#!/usr/bin/env python3
"""Reproducible FishBase image URL catalog; network is explicit and optional.

Usage: --download retrieves the pinned picture metadata; --check-urls records
live page/license and image checks. With no options, build entirely offline.
Existing project-to-FishBase mappings are reused without taxonomy changes.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import platform
import re
import urllib.error
import urllib.parse
import urllib.request

import pandas as pd
import pyarrow
import pyarrow.parquet as pq
import openpyxl

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'Data/FishImages/raw/v26.06'
OUT = ROOT / 'Output/FishImages'
CROSS = ROOT / 'Output/LifeHistory/taxon_crosswalk.csv'
ROSTER = ROOT / 'Output/SpeciesSelection/species_investigation_queue.csv'
HOST = 'https://www.fishbase.se'
SOURCE = 'https://s3.us-west-2.amazonaws.com/us-west-2.opendata.source.coop/cboettig/fishbase/fb/v26.06/parquet/picturesmain.parquet'
VERSION = '26.06'
CHECKS = ROOT / 'Data/FishImages/url_checks.json'
PAGES = ROOT / 'Data/FishImages/source_pages'
SUPPLEMENTS = ROOT / 'config/fish_image_supplements.csv'
SUPPLEMENT_CHECKS = ROOT / 'Data/FishImages/supplemental_url_checks.json'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def now():
    return datetime.now(timezone.utc).isoformat()


def text(value):
    return '' if pd.isna(value) else str(value)


def download():
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / 'picturesmain.parquet'
    manifest_path = RAW / 'download_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    if path.exists() and 'picturesmain' in manifest:
        if sha(path.read_bytes()) != manifest['picturesmain']['sha256']:
            raise ValueError('Picture metadata checksum mismatch')
        return
    with urllib.request.urlopen(SOURCE, timeout=60) as response:
        data = response.read()
        modified = response.headers.get('Last-Modified', '')
    if not (data.startswith(b'PAR1') and data.endswith(b'PAR1')):
        raise ValueError('Invalid picture metadata response')
    path.write_bytes(data)
    manifest['picturesmain'] = dict(url=SOURCE, version=VERSION, bytes=len(data),
        sha256=sha(data), retrieved_utc=now(), last_modified_http=modified)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True)+'\n')


def eligible(row):
    """Whole fish images suitable as adult/unsexed species illustrations."""
    return (row['Scanned'] == 1 and row['LifeStage'] in ['unsexed', 'male', 'female']
            and row['PictureType'] not in ['stamp', 'fish details']
            and bool(re.fullmatch(r'[A-Za-z0-9_. -]+\.(?:jpg|jpeg|png|gif)', text(row['PicName']), re.I)))


def priority(row):
    rights = {'free use': 1, 'non-commercial use': 2, 'permission required': 4}
    return (0 if row['PublicDomain'] else rights.get(text(row['Copyright']), 3),
            not bool(row['PicPreferred']),
            'photo' not in text(row['PictureType']).lower(), int(row['autoctr']))


def urls(code, filename):
    return (HOST+'/images/species/'+urllib.parse.quote(filename),
            HOST+'/photos/PicturesSummary.php?'+urllib.parse.urlencode(
                {'ID':int(float(code)), 'what':'species', 'pic':filename}))


class PicturePage(HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []
        self.licenses = []
        self.words = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'img':
            self.images.append(attrs.get('src', ''))
        if tag == 'a' and 'license' in attrs.get('rel', '').split():
            self.licenses.append(attrs.get('href', ''))

    def handle_data(self, data):
        self.words.append(data)


def page_rights(html, filename):
    parser = PicturePage()
    parser.feed(html)
    matched = any(urllib.parse.unquote(urllib.parse.urlparse(src).path).endswith('/'+filename)
                  for src in parser.images)
    if not matched:
        return dict(page_image_match=False, license='', license_url='', reuse_status='page_image_mismatch')
    words = ' '.join(parser.words)
    if 'ALL RIGHTS RESERVED' in words.upper():
        return dict(page_image_match=True, license='All rights reserved', license_url='',
                    reuse_status='permission_required')
    licenses = set()
    for link in parser.licenses:
        parsed = urllib.parse.urlparse(link)
        if parsed.hostname not in ['creativecommons.org', 'www.creativecommons.org']:
            continue
        match = re.fullmatch(r'/licenses/(by|by-nc)/(\d\.\d)/?', parsed.path)
        if match:
            licenses.add((match[1], match[2]))
    # This is the picture-specific block, not a website/database footer.
    if len(licenses) == 1 and re.search(r'image can be freely', words, re.I):
        kind, version = next(iter(licenses))
        return dict(page_image_match=True, license='CC '+kind.upper()+' '+version,
                    license_url=f'https://creativecommons.org/licenses/{kind}/{version}/',
                    reuse_status='attribution_noncommercial' if 'nc' in kind else 'attribution_required')
    return dict(page_image_match=True, license='', license_url='', reuse_status='license_unverified')


def probe(candidate):
    picture_id = str(int(candidate['autoctr']))
    image_url, page_url = urls(candidate['SpecCode'], candidate['PicName'])
    result = dict(picture_id=picture_id, image_url=image_url, image_page_url=page_url,
                  checked_utc=now(), image_status='not_checked', reuse_status='license_unverified',
                  license='', license_url='', page_image_match=False)
    try:
        with urllib.request.urlopen(page_url, timeout=25) as response:
            html = response.read(2_000_001)
            if len(html) > 2_000_000:
                raise ValueError('Oversize image page')
            result['page_http_status'] = response.status
            result['page_final_url'] = response.url
        path = PAGES/f'{picture_id}.html'
        path.write_bytes(html)
        result.update(page_rights(html.decode('utf8', errors='replace'), candidate['PicName']))
        result['page_cache'] = str(path.relative_to(ROOT))
        result['page_sha256'] = sha(html)
    except Exception as error:
        result['page_error'] = f'{type(error).__name__}: {error}'
    try:
        with urllib.request.urlopen(image_url, timeout=25) as response:
            data = response.read(16_000_001)
            result['image_http_status'] = response.status
            result['image_final_url'] = response.url
            result['image_content_type'] = response.headers.get('Content-Type', '')
        signature = data.startswith((b'\xff\xd8\xff', b'GIF87a', b'GIF89a', b'\x89PNG\r\n\x1a\n'))
        if len(data) > 16_000_000:
            result['image_status'] = 'oversize_response'
        elif signature and result['image_content_type'].lower().startswith('image/'):
            result['image_status'] = 'verified_image_response'
            result['image_sha256'] = sha(data)
            result['image_bytes'] = len(data)
        else:
            result['image_status'] = 'not_an_image_response'
    except Exception as error:
        result['image_status'] = 'request_failed'
        result['image_error'] = f'{type(error).__name__}: {error}'
    return picture_id, result


def load_inputs():
    manifest = json.loads((RAW/'download_manifest.json').read_text())
    data = (RAW/'picturesmain.parquet').read_bytes()
    if manifest['picturesmain']['version'] != VERSION or sha(data) != manifest['picturesmain']['sha256']:
        raise ValueError('Pinned picture metadata failed validation')
    pictures = pq.read_table(RAW/'picturesmain.parquet').to_pandas(timestamp_as_object=True)
    roster = pd.read_csv(ROSTER, keep_default_na=False)
    cross = pd.read_csv(CROSS, keep_default_na=False)
    if len(roster) != 80 or not roster.species.is_unique or not cross.species.is_unique:
        raise ValueError('Expected 80 unique project species and a unique taxon crosswalk')
    if set(roster.species) != set(cross.species):
        raise ValueError('Roster/crosswalk mismatch')
    mappings = roster[['species']].merge(cross,on='species',validate='one_to_one')
    attached = mappings.loc[mappings.attach_traits == 1, 'attached_spec_code']
    if not attached.is_unique or attached.eq('').any():
        raise ValueError('Ambiguous attached source taxon')
    groups = {}
    for mapping in mappings.to_dict('records'):
        if not mapping['attach_traits']:
            groups[mapping['species']] = []
            continue
        selected = pictures[pictures.SpecCode == float(mapping['attached_spec_code'])]
        groups[mapping['species']] = sorted(selected.to_dict('records'), key=priority)
    return mappings, groups, manifest


def supplemental_checks(supplements, refresh=False):
    """Check curated external leads without treating them as approved images."""
    checks=json.loads(SUPPLEMENT_CHECKS.read_text()) if SUPPLEMENT_CHECKS.exists() else {}
    for r in supplements.to_dict('records'):
        if r['species'] in checks and not refresh:
            continue
        with urllib.request.urlopen(r['supplemental_source_url'],timeout=25) as response:
            page=response.read()
        path=ROOT/r['source_page_cache']
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(page)
        with urllib.request.urlopen(r['supplemental_image_url'],timeout=25) as response:
            data=response.read(16_000_001)
            mime=response.headers.get('Content-Type','')
            status=response.status
        valid=data.startswith((b'\xff\xd8\xff',b'GIF87a',b'GIF89a',b'\x89PNG\r\n\x1a\n')) and mime.startswith('image/') and len(data)<=16_000_000
        checks[r['species']]=dict(image_url=r['supplemental_image_url'],http_status=status,
            content_type=mime,sha256=sha(data),bytes=len(data),checked_utc=now(),
            image_status='verified_image_response' if valid else 'not_an_image_response')
    SUPPLEMENT_CHECKS.write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
    return checks


def build(check_urls=False, refresh=False):
    OUT.mkdir(parents=True, exist_ok=True)
    mappings, groups, download_meta = load_inputs()
    supplements=pd.read_csv(SUPPLEMENTS,keep_default_na=False)
    if not supplements.species.is_unique or not set(supplements.species).issubset(set(mappings.species)):
        raise ValueError('Supplement species keys are not unique roster members')
    external_checks=json.loads(SUPPLEMENT_CHECKS.read_text()) if SUPPLEMENT_CHECKS.exists() else {}
    if check_urls:
        external_checks=supplemental_checks(supplements,refresh=refresh)
    checks = json.loads(CHECKS.read_text()) if CHECKS.exists() else {}
    if check_urls:
        PAGES.mkdir(parents=True, exist_ok=True)
        first = [next(r for r in rows if eligible(r)) for rows in groups.values() if any(eligible(r) for r in rows)]
        pending = [r for r in first if refresh or str(int(r['autoctr'])) not in checks]
        with ThreadPoolExecutor(max_workers=4) as pool:
            for i,(pid,result) in enumerate(pool.map(probe,pending),1):
                checks[pid] = result
                # Persist incrementally so interruptions do not discard checks.
                CHECKS.write_text(json.dumps(checks,indent=2,sort_keys=True)+'\n')
                if i % 10 == 0 or i == len(pending):
                    print(f'Checked {i}/{len(pending)} selected images',flush=True)
    for check in checks.values():
        if 'page_cache' in check and sha((ROOT/check['page_cache']).read_bytes()) != check['page_sha256']:
            raise ValueError('Cached source page checksum mismatch')
    rows, candidates = [], []
    for mapping in mappings.to_dict('records'):
        species = mapping['species']
        available = [r for r in groups[species] if eligible(r)]
        selected = available[0] if available else None
        code = int(float(mapping['attached_spec_code'])) if mapping['attach_traits'] else ''
        item = dict(species=species,fishbase_name=mapping['fishbase_name'] if mapping['attach_traits'] else '',
                    fishbase_spec_code=code,taxon_match_status=mapping['match_status'],
                    image_status='taxonomy_unresolved' if not mapping['attach_traits'] else 'no_species_image_in_snapshot',
                    image_url='',image_page_url='',gallery_url=HOST+f'/photos/ThumbnailsSummary.php?ID={int(float(code))}' if code!='' else '',
                    picture_id='',picture_filename='',image_type='',life_stage='',credit='',attribution='',
                    source_copyright='',source_public_domain_flag='',license='',license_url='',
                    reuse_status='not_applicable',eligible_for_noncommercial_embedding=False,
                    page_image_match=False,checked_utc='',image_http_status='',image_content_type='',
                    image_sha256='',image_bytes='',source_assignment_review='not_independently_verified',
                    candidate_count=len(groups[species]),eligible_candidate_count=len(available),fishbase_version=VERSION)
        if selected:
            r=selected
            pid=str(int(r['autoctr']))
            image_url,page_url=urls(code,r['PicName'])
            check=checks.get(pid,{})
            # A cached check applies only to the exact URLs being exported.
            if check and (check['image_url']!=image_url or check['image_page_url']!=page_url):
                raise ValueError('Image check URL mismatch')
            item.update(image_url=image_url,image_page_url=page_url,picture_id=pid,
                picture_filename=r['PicName'],image_type=text(r['PictureType']),life_stage=text(r['LifeStage']),
                credit=text(r['AuthName']),source_copyright=text(r['Copyright']),
                source_public_domain_flag=bool(r['PublicDomain']),image_status=check.get('image_status','url_not_checked'),
                license=check.get('license',''),license_url=check.get('license_url',''),
                reuse_status=check.get('reuse_status','license_unverified'),
                page_image_match=check.get('page_image_match',False),checked_utc=check.get('checked_utc',''),
                image_http_status=check.get('image_http_status',''),image_content_type=check.get('image_content_type',''),
                image_sha256=check.get('image_sha256',''),image_bytes=check.get('image_bytes',''))
            item['eligible_for_noncommercial_embedding']=bool(
                item['image_status']=='verified_image_response' and item['page_image_match']
                and item['reuse_status'] in ['attribution_required','attribution_noncommercial']
                and item['credit'])
            item['attribution']=f'{species} — {item["credit"] or "credit unavailable"}, from FishBase'
            if item['license']:
                item['attribution']+='; '+item['license']
            if mapping['fishbase_name']!=species:
                item['attribution']+=f'; source identification: {mapping["fishbase_name"]}'
        for field in supplements.columns:
            if field!='species':
                item[field]=''
        item['supplemental_image_status']='not_applicable'
        item['supplemental_checked_utc']=''
        supplement=supplements[supplements.species==species]
        if len(supplement):
            item.update({k:v for k,v in supplement.iloc[0].to_dict().items() if k!='species'})
            external=external_checks.get(species,{})
            if external and external['image_url']!=item['supplemental_image_url']:
                raise ValueError('Supplemental image check URL mismatch')
            item['supplemental_image_status']=external.get('image_status','not_checked')
            item['supplemental_checked_utc']=external.get('checked_utc','')
        rows.append(item)
        for rank,r in enumerate(groups[species],1):
            image_url,page_url=urls(code,r['PicName']) if text(r['PicName']) else ('','')
            candidates.append(dict(species=species,fishbase_name=mapping['fishbase_name'],
                fishbase_spec_code=int(float(code)),picture_id=int(r['autoctr']),picture_filename=text(r['PicName']),
                source_picture_name=f'{text(r["PicGenus"])} {text(r["PicSpecies"])}'.strip(),
                image_type=text(r['PictureType']),life_stage=text(r['LifeStage']),
                credit=text(r['AuthName']),source_copyright=text(r['Copyright']),
                source_public_domain_flag=bool(r['PublicDomain']),source_preferred=bool(r['PicPreferred']),
                scanned=r['Scanned'],reference_id=text(r['Reference']),image_url=image_url,image_page_url=page_url,
                eligible=eligible(r),selection_priority=rank,selected=bool(selected and r['autoctr']==selected['autoctr']),
                url_status=checks.get(str(int(r['autoctr'])),{}).get('image_status','not_checked'),
                source_table='picturesmain',source_version=VERSION,
                source_sha256=download_meta['picturesmain']['sha256']))
    frame=pd.DataFrame(rows)
    all_candidates=pd.DataFrame(candidates)
    frame.to_csv(OUT/'fish_images_80_species.csv',index=False)
    all_candidates.to_csv(OUT/'image_candidates.csv',index=False)
    (OUT/'fish_images_80_species.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n')
    coverage=dict(species=len(frame),species_with_image_url=int(frame.image_url.ne('').sum()),
        verified_image_urls=int(frame.image_status.eq('verified_image_response').sum()),
        eligible_for_noncommercial_embedding=int(frame.eligible_for_noncommercial_embedding.sum()),
        permission_required=int(frame.reuse_status.eq('permission_required').sum()),
        status_counts=frame.image_status.value_counts().to_dict(),
        reuse_status_counts=frame.reuse_status.value_counts().to_dict(),candidate_records=len(all_candidates))
    coverage['species_with_image_or_supplemental_url']=int((frame.image_url.ne('')|frame.supplemental_image_url.ne('')).sum())
    coverage['supplemental_urls_verified']=int(frame.supplemental_image_status.eq('verified_image_response').sum())
    (OUT/'coverage.json').write_text(json.dumps(coverage,indent=2,sort_keys=True)+'\n')
    notes=pd.DataFrame([
        ('Purpose','Image URLs for the existing 80 species; not specimen vouchers or independently verified identifications.'),
        ('Source','FishBase picturesmain snapshot v26.06; source URLs and credits retained.'),
        ('Selection','Scanned whole-fish adult/unsexed images; prefer source reuse terms, then FishBase preferred flag, photos and source row ID.'),
        ('Rights','Use eligible_for_noncommercial_embedding only with full credit, license and source links. Other URLs are for source discovery.'),
        ('License','Live picture-specific license prevails in this catalog over coarse snapshot labels; cached HTML is the evidence.'),
        ('Missing','No substitute species or family pictograms assigned. Unresolved taxonomy stays unresolved.'),
        ('External leads','Two supplemental URLs have separate review statuses; neither is approved for automatic embedding. The historical M. opalinum figure does not resolve synonymy.'),
        ('Rebuild','python3 Scripts/build_fish_image_catalog.py (offline). --download and --check-urls are explicit network steps.'),
        ('URL lifetime','Checks are dated. Remote URLs/content can change; archive permitted images with attribution for frozen reports.')],columns=['topic','note'])
    with pd.ExcelWriter(OUT/'fish_images_80_species.xlsx',engine='openpyxl') as writer:
        for title,data in [('Read me',notes),('80 species',frame),('All candidates',all_candidates)]:
            data.to_excel(writer,sheet_name=title,index=False)
            ws=writer.sheets[title]
            ws.freeze_panes='B2';ws.auto_filter.ref=ws.dimensions
            for cells in ws.iter_cols():
                header=str(cells[0].value)
                ws.column_dimensions[cells[0].column_letter].width=min(55,max(18,len(header)+2))
                if header.endswith('_url'):
                    for cell in cells[1:]:
                        if cell.value:
                            cell.hyperlink=cell.value;cell.style='Hyperlink'
            for cell in ws[1]:
                cell.font=openpyxl.styles.Font(bold=True,color='FFFFFF')
                cell.fill=openpyxl.styles.PatternFill('solid',fgColor='254B63')
    inputs=[CROSS,ROSTER,RAW/'download_manifest.json',RAW/'picturesmain.parquet',Path(__file__).resolve(),SUPPLEMENTS]
    inputs.extend([ROOT/'docs/fish_image_catalog.md',ROOT/'tests/test_fish_image_catalog.py',
                   ROOT/'requirements-life-history.txt'])
    if CHECKS.exists(): inputs.append(CHECKS)
    if SUPPLEMENT_CHECKS.exists(): inputs.append(SUPPLEMENT_CHECKS)
    inputs.extend(ROOT/p for p in supplements.source_page_cache)
    paths=[p for p in OUT.iterdir() if p.is_file() and p.name not in ['build_manifest.json','validation_report.json']]
    manifest=dict(command='python3 Scripts/build_fish_image_catalog.py',fishbase_version=VERSION,
        software=dict(python=platform.python_version(),pandas=pd.__version__,pyarrow=pyarrow.__version__,openpyxl=openpyxl.__version__),
        inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in inputs},
        outputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(paths)},
        snapshot=download_meta['picturesmain'],coverage=coverage,
        reproducibility='CSV/JSON tables deterministic from frozen inputs; workbook ZIP timestamps may differ.')
    (OUT/'build_manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    print(json.dumps(coverage,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download',action='store_true')
    parser.add_argument('--check-urls',action='store_true')
    parser.add_argument('--refresh-checks',action='store_true',help='Explicitly replace prior URL checks and cached image pages')
    args=parser.parse_args()
    if args.refresh_checks and not args.check_urls:
        parser.error('--refresh-checks requires --check-urls')
    if args.download: download()
    build(check_urls=args.check_urls,refresh=args.refresh_checks)
