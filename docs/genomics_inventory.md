# Public genomic inventory: sources, methods and interpretation

This workflow inventories the existing 80-species roster for nuclear whole-genome
sequencing (WGS), including low-coverage sequencing and genome skimming, and genome
assemblies with annotation evidence. It produces a separate evidence database for
future contemporary sampling maps. It does not merge records into the museum atlas
or infer a completed temporal study design.

## Discovery scope and provenance

1. Resolve each project name using ENA's exact any-name taxonomy service. Archive
   names and taxon IDs are stored alongside the original species key.
2. Query ENA `read_run` with `tax_tree(taxid) AND (library_source="GENOMIC" OR
   library_strategy="WGS")`, all fields specified, `limit=0`. Descendant taxa are
   included. This retrieves ENA-hosted metadata for INSDC accessions, including
   SRA and DDBJ deposits, without counting database mirrors separately.
3. Retrieve paginated NCBI Datasets genome assembly reports for the same taxon.
4. Retrieve full sample XML, assembly-linked BioSample attributes, and project
   descriptions. Record the source of every attribute and preserve conflicting
   values rather than replacing them silently.
5. Save compressed original responses, complete request URLs, retrieval times,
   SHA256s, input fingerprints and the R session. Missing/failed queries are not
   interpreted as zero results. Species-query failures stop the build.

These are public-archive discovery results, not proof that all data ever generated
have been found. Private/embargoed studies, archive indexing lag, misidentified or
misclassified deposits, non-INSDC institutional repositories, and annotation files
available only in paper supplements, Dryad/Zenodo or lab websites are not exhaustively
searched. No read alignment, base-quality assessment or assembly-file download is
performed. The snapshot date is in `queries.csv`; it is not a collection date.

Primary documentation:

- [ENA advanced search and complete-result retrieval](https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access/advanced-search.html)
- [ENA taxonomic search](https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access/taxon-based-search.html)
- [NCBI genome report schema](https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/data-reports/genome-assembly/)
- [NCBI BioSample attribute definitions](https://www.ncbi.nlm.nih.gov/biosample/docs/attributes/)

## Taxonomic decisions

Original project names are never replaced. Approved project synonyms are documented
in `config/life_history_taxon_crosswalk.csv`; the genomic lookup keeps independent
NCBI/ENA taxon IDs. Automatic assignment requires one exact any-name result.

- `Coelorinchus carminatus`: search the documented NCBI subspecies
  `Coelorinchus caelorhincus carminatus` (1266865), not all parent-species populations.
- `Helicolenus maderensis`: use the project's Goode & Bean authority-resolved
  `H. dactylopterus` mapping. The different Valenciennes homonym is excluded.
- `Myctophum opalinum`: withhold transfer to `M. affine`, which is a separate project
  species. Counts under this unresolved name are unknown, not evidence of absence.
- Other changed combinations returned by the exact taxonomy service remain linked
  to their original project species and the cached source response.

Regional/subspecies identity still requires population-level review, even when the
archive taxonomic assignment is unambiguous.

## Assemblies and annotation

`assemblies.csv` retains each versioned GCA/GCF record, status, assembly level,
sequence length, contig/scaffold N50, sequencing technology and linked BioSample.
Paired GenBank/RefSeq accessions are linked with `assembly_pair_key`; neither paired
representations nor separate haplotypes imply additional fish.

Annotation evidence comes from NCBI `annotation_info`: provider, release, pipeline,
method, and gene/protein-coding counts when reported. Annotation presence and
NCBI reference/representative designation are separate facts. Missing annotation
information is **not reported**, not a verified absence of external gene models.
Assembly release dates and annotation dates are not specimen collection years.
Suppressed records remain in the audit. `annotation_recorded` preserves their annotation evidence, but `annotation_available` and summary annotation counts require current status; suppressed annotations are not reported as available references.

## Assay classification and nominal coverage

The run table retains every genomic result. WGS inclusion is based on its library
strategy, with experiment/library evidence overriding mislabeled RAD, GBS,
restriction-digest, targeted-capture and Hi-C records. Bisulfite/methylation assays,
organelle-target records, whole-genome amplification and ambiguous `OTHER` records
remain distinct. A study can contain both WGS and other assays; a broad study title
does not make all its runs WGS. `config/genomics_assay_overrides.csv` contains
explicitly reviewed exceptions with accession, rationale and evidence URL.

Two separate low-coverage indicators are provided:

- `explicit_low_coverage_label`: low-coverage/low-pass/genome-skim wording in
  experiment/library metadata, or an evidence-backed curated exception.
- `nominal_low_depth_candidate`: summed short-read WGS bases for a BioSample divided
  by the selected assembly length, at or below the configurable 10× screening
  cutoff. This is **nominal unaligned yield**, not observed genomic coverage.

Reference selection for that denominator favors a current reference-designated
assembly, then an annotated assembly, chromosome level and scaffold N50. The chosen
accession is retained. Without an appropriate assembly or usable base counts,
nominal depth is missing. Long-read yields remain in WGS totals but are not combined
with short reads for this estimate. Identical complete FASTQ checksum sets are
flagged and contribute yield once; other technical overlap may still be undetected.
Depth for pools is per archived pooled sample, not per fish. QC, contamination,
duplicates, read overlap, ploidy and mappability can change realized coverage.

## Sample identity, collection dates and geographic evidence

The sample key is `(species, sample_accession)`. All linked runs and assemblies
attach to that key. Multiple runs do not become multiple specimens. Repeated
voucher/isolate identifiers within the same study set are flagged as possible
individual duplicates. Explicit `_Run1`, `_Run2`, etc. isolate suffixes also supply
a `replicate_identity_hint` across split projects; these are flags, not automatic
biological merges. Unidentified duplicates across submissions can remain.

Only allowlisted collection fields supply years (`collection_date`, collection/
sampling year, `yearCollected`, etc.). A single unambiguous year is assigned; a
range spanning years or conflicting dates remains unassigned, with its endpoints
and source strings retained. Approximate/before/after dates are review cases.
Submission, publication, sequencing and annotation dates never fill missing
collection years. Unparsed ancient dates are retained as raw evidence.

Coordinates come from sample `lat_lon`, numeric latitude/longitude aliases
(including Darwin Core `decimalLatitude`/`decimalLongitude` and custom `Sample lat`/
`Sample long`), or explicit hemisphere-marked coordinates embedded in the collection
locality text. Valid ranges and coordinate agreement are checked; `(0,0)` and
conflicts greater than 0.02° are rejected. Numerically identical coordinate aliases
at floating-point precision are consolidated. No city/country centroids, institutional
addresses, sequencing locations, or study-wide locations are silently assigned.
Missing or ambiguous positions remain in the review queue. Reported coordinates
can still be approximate or inaccurate; no independent georeferencing validation
is claimed. Explicit coordinates parsed from locality text retain that source label.

Life stage is recorded as larva, adult, juvenile, embryo/egg, mixed or unknown from explicit
stage metadata. Missing stages are not assumed mature in this database. Pool,
captive/cross, hybrid and cell-line flags use biological sample attributes; a pooled
sequencing library is not by itself evidence of multiple fish.

## Mapping and selection

`atlas_candidates.csv` requires WGS, a single post-1930 collection year, reported
coordinates inside the atlas window (longitude −100 to −50, latitude 5 to 60),
and no detected pool/captive/cell-line/hybrid/duplicate-individual flags. This is
an automatic screen, not verification that each accession is one independent fish.
`specimen_count` stays blank until reviewed; cell counts explicitly count BioSamples.
Cells have the same 2° size and origin as the existing atlas. The bounding box can
include freshwater, inland, or introduced populations: basin/habitat and wild-origin
review is required before ecological comparisons.

To prioritize species, consider independent wild WGS individuals at matching
historical sites, comparable years and life stages, usable short-read depth, an
appropriate annotated reference and geographic gaps that can be filled. A large
number of laboratory runs or an annotated genome from one fish cannot substitute
for geographically matched contemporary replication. Use `studies.csv` to recover
missing dates/localities from accession-linked publication supplements first;
then record any reviewed corrections in an evidence-backed curation table before
integrating with the atlas. Do not propagate a paper-wide year/location to every
sample unless its sample mapping supports it.

## Main field dictionary

| Fields | Meaning |
| --- | --- |
| `species`, `archive_name`, `tax_id` | Project key, archive label, taxonomy ID |
| `query_status`, `*_availability` | Completed search versus unresolved taxonomy; found versus not returned |
| `assembly_records`, `assembly_pairs` | Assembly records and paired GCA/GCF group counts, not fish |
| `annotation_available`, `reference_designated` | Annotation evidence and separate reference designation |
| `wgs_runs`, `wgs_samples` | Eligible run accessions and distinct BioSample accessions |
| `study_key` | Primary project accession, otherwise secondary study accession |
| `collection_date_raw`, `year_start`, `year_end`, `year`, `date_status` | Original date evidence, interval, assignable year and parsing status |
| `locality_raw`, `coordinates_raw`, `latitude`, `longitude`, `coordinate_status` | Collection-location evidence and conservative coordinate interpretation |
| `life_stage`, `life_stage_raw` | Parsed and submitted life stage |
| `material_status`, `*_flag` | Pool/captive/cell-line/hybrid evidence requiring special treatment |
| `possible_duplicate_individual` | Repeated voucher/isolate lead; no automatic specimen merge |
| `wgs_bases`, `short_read_wgs_bases`, `nominal_depth`, `depth_reference_accession` | Yield totals, nominal depth and explicit denominator provenance |
| `explicit_low_coverage_label`, `nominal_low_depth_candidate` | Submitter/curated wording versus an analytical screening estimate |
| `within_atlas_bounds`, `post_1930`, `map_candidate`, `review_reason` | Individual screening decisions and remaining review needs |
| `sample_count`, `count_unit`, `specimen_count`, `integration_status` | Explicit BioSample counting; no inferred independent-fish count |
| `source_url`, `retrieved_utc`, `sha256` | Record/request provenance and exact snapshot verification |

CSV blank values represent missing data. In SQLite, blanks become SQL NULL;
boolean values are stored as the explicit text `TRUE`/`FALSE`. Accessions remain
text. Common measures/counts have numeric affinity; raw attribute values remain
text so archive content is preserved. Python/SQLite exports are transport only;
the scientific decisions and summary report are built in R.
