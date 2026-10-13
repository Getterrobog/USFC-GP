# Image metadata and verification evidence

`raw/v26.06/picturesmain.parquet` is the unmodified FishBase picture table,
release 26.06, from [Source Cooperative](https://source.coop/cboettig/fishbase),
curated by Carl Boettiger from FishBase team data. Its manifest records the
source URL, retrieval time and SHA-256. Metadata use the provider's CC BY-NC 4.0
terms; **individual images have their own rights**.

`url_checks.json` records verified image responses and hashes of the individual
FishBase image pages in `source_pages/`. Supplemental source pages and URL checks
support two separately flagged external image leads. The historical Jordan volume
is hosted by Project Gutenberg; the *Prionotus martis* image is credited to FAO
on its STRI page. These external sources do not inherit the FishBase license.

Image files are not included. Public contributor credits come from the picture
records; no collaborator contact table is retained. See the
[workflow](../../docs/fish_image_catalog.md) for acquisition and offline rebuilds.
