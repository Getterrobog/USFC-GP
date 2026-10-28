# Species illustrations

These 54 local images appear in both [atlas pages](../index.html), including the
[all-year overview](../overview.html). They are representative species
illustrations, not photographs of the sampled museum lots. Source life-stage and
taxonomic applicability notes accompany the images.

Files preserve the original image bytes from the existing
[FishImages catalog](../../FishImages/README.md). Only rows marked
`eligible_for_noncommercial_embedding` are cached. Each selected image is licensed
CC BY-NC 4.0; keep the contributor credit, FishBase source link and license link
with it. The remaining 26 species have source links and permission/taxonomic
review notes in the viewer instead of embedded images.

[download_manifest.csv](download_manifest.csv) records source URLs, retrieval
times, byte counts, SHA-256 hashes and the absence of image alterations.
[species_images.csv](../tables/species_images.csv) preserves the full catalog
metadata and each species' display status. Both pages use relative image paths
and work offline; visiting source/license links requires an internet connection.

From the repository root:

```bash
# Explicit network step; skips and verifies images already cached.
Rscript Scripts/cache_sampling_atlas_images.R --download
# Verify the cache without network access.
Rscript Scripts/cache_sampling_atlas_images.R
# Refresh both pages using saved images and metadata.
Rscript Scripts/refresh_sampling_atlas_index.R
Rscript tests/test_atlas_images.R
```

The caching script uses base R and the system `sha256sum` utility. Changed image
bytes stop the build rather than silently replacing the catalog's verified image.
