# Species image URLs for webpages and reports

Compiled 12 October 2026. The [workbook](../Output/FishImages/fish_images_80_species.xlsx),
[CSV](../Output/FishImages/fish_images_80_species.csv) and
[JSON](../Output/FishImages/fish_images_80_species.json) retain all 80 project species.
They reuse the existing life-history taxon crosswalk and species-level pooling.
No atlas pages, life-history traits or taxonomic decisions are modified.

## Coverage

| Result | Species |
| --- | ---: |
| Verified FishBase image URL | 78 |
| Selected FishBase image licensed CC BY-NC 4.0 on its individual page | 54 |
| Selected FishBase image requires permission | 24 |
| External image lead for a FishBase gap | 2 |
| Image URL or separately flagged external lead | 80 |

The catalog includes both photographs and scientific drawings. Verification means
an HTTP 200 response with an image MIME type and JPEG/GIF/PNG signature; it is not
an independent visual or taxonomic identification. Selected FishBase picture pages
also contain the expected image filename. Checks retain UTC time, response type,
byte count and image SHA-256. Image files themselves are not bundled.

Two supplemental URLs are deliberately separate from `image_url`:

- **Prionotus martis:** no species picture in the pinned FishBase table. An
  [FAO illustration hosted by STRI](https://biogeodb.stri.si.edu/caribbean/en/pages/random/5461)
  is available as a direct JPEG. Its individual credit page explicitly requires
  permission. A generic FishBase family drawing is not substituted.
- **Myctophum opalinum:** FishBase attachment remains withheld because of its
  uncertain synonymy with *M. affine*. An exact-name historical illustration is
  available in [Jordan (1905), volume II, p. 133, figure 93](https://www.gutenberg.org/cache/epub/51702/pg51702-images.html#img_images_i_133a.jpg).
  It is a historical illustration under that name, not evidence resolving the
  current taxonomic identity. Its source and review status must accompany any
  later use. Project Gutenberg terms are linked from the source; this is not a
  FishBase-licensed image.

## Sources and selection

Picture metadata come from FishBase `picturesmain`, release **26.06**, via the
[Source Cooperative snapshots](https://source.coop/cboettig/fishbase).
The full unchanged Parquet file and its acquisition manifest are archived under
`Data/FishImages/raw/v26.06/`. Picture-level credits are retained directly from
`AuthName`; collaborator contact data are not needed or included.

There are **523 picture records** attached to the 78 matched taxa with pictures.
All are retained in `image_candidates.csv`, including excluded stages and picture
types. The selected representative must be marked scanned, have a suitable image
filename, be labelled male/female/unsexed, and not be classified as a stamp or fish
detail. Unsexed does not independently establish adult maturity. Eggs, larvae,
juveniles and otolith images are not chosen as the representative species image.

Among eligible records the deterministic order is: source public-domain flag,
then source `free use`, `non-commercial use`, unspecified rights, and
`permission required`; within each level prefer the FishBase preferred-picture
flag, then photo types, then ascending source picture ID. These coarse source
labels are used only for candidate ordering. The selected image's **live individual
picture page** establishes the recorded license and reuse status. In this release,
all 54 selected reusable images show CC BY-NC 4.0, including images whose older
snapshot metadata used a different/coarser label. A generic website license is
not accepted as an image license.

Image URLs follow the actual FishBase species-image links. Each record also
includes its particular image page (with filename parameter), species gallery,
source picture ID, image type, stage, contributor credit, source taxon name,
project-to-source match status and ready-to-use attribution text. Exact project
names remain the join keys even when FishBase uses a documented alias. Images
assigned to broader source taxa inherit the same applicability limitation as
the life-history crosswalk.

## Using the catalog

For noncommercial project webpages/reports, filter on
`eligible_for_noncommercial_embedding == true`. This flag requires a verified image
response, a matching image on its individual page, an explicit supported image
license and contributor credit. Display the attribution beside the image and link
to both `image_page_url` and `license_url`. FishBase asks that reused images credit
the person/organization and identify FishBase as the source; see its
[reuse statement](https://www.fishbase.org/search.cfm).

For example, a renderer can join the JSON records by `species`, use `image_url` as
the image source, and use `attribution` as its caption. For records failing the
embedding flag, show a source-page link or an explicit unavailable-image label.
Treat supplemental leads as review items, not automatically approved substitutes.
The flag concerns the documented noncommercial use case; it does not authorize
commercial publication or remove a license's attribution requirements.

Use these as species illustrations, not photographs of the actual sampled museum
specimens. Check scientific suitability, sex/stage and any taxonomic exceptions
when choosing final report images. Remote images can change or disappear. For a
frozen report release, retain a permitted local copy, credit, source/license page,
access date and content hash together; record any crop or alteration. Current URL
verification is not a guarantee of future availability or hotlink behavior.

## Files and reproducibility

- `fish_images_80_species.csv/.json/.xlsx`: one row per project species.
- `image_candidates.csv`: every attached source picture and its selection status.
- `coverage.json`: counts of URL, license and supplemental coverage.
- `build_manifest.json`: code/input/output hashes, software and source metadata.
- `Data/FishImages/url_checks.json`: dated FishBase checks and cached-page hashes.
- `Data/FishImages/source_pages/`: source HTML retained for license/identity audit.
- `config/fish_image_supplements.csv`: explicit, sourced external leads.
- `Data/FishImages/supplemental_url_checks.json`: direct-image checks for those leads.

Use the Python environment pinned in `requirements-life-history.txt`. Normal
rebuilds require no network:

```bash
python3 Scripts/build_fish_image_catalog.py
python3 -m unittest discover -s tests -p test_fish_image_catalog.py -v
```

Acquisition and live verification are explicit:

```bash
python3 Scripts/build_fish_image_catalog.py --download --check-urls
```

Cached checks are reused. To intentionally update live evidence, archive the prior
release first, then run with `--check-urls --refresh-checks`. This replaces the
check timestamps and cached picture pages; changed source data can change the
result. Source metadata and cached FishBase pages fail checksum validation if
altered unexpectedly. CSV/JSON tables rebuild deterministically from the archived
inputs; Excel ZIP timestamps can vary.

Tests cover all 80 keys, successful image responses, representative-stage rules,
withheld taxonomy, image-specific license parsing, embedding conditions, external
lead separation, source-page checksums and workbook readability. An offline
rebuild with network access disabled in the Python process checks that the saved
catalog can be reconstructed without contacting FishBase.
