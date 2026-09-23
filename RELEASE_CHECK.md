# Release check — paper-j1-multiverse-jlps-replication

Date: 2026-09-23T10:27:33Z. Snapshot downloaded anonymously (no credentials, no gh CLI) from `https://codeload.github.com/sokubo/paper-j1-multiverse-jlps-replication/tar.gz/main`.

- ref: `main`; commit: `46be81461aa436f1bab774e91757b35e89b44901`
- archive SHA-256: `fce1d98b3111ebc7ff088c662bb11b7c86a73063e8707bbe6295250077cd5591`
- files in snapshot (excluding FILE_MANIFEST.txt and RELEASE_CHECK*): 37; listed in FILE_MANIFEST.txt: 37; missing from snapshot: 0; not listed in manifest: 0
- clean run: documented sequence executed in a clean copy with shipped outputs set aside (69s); log and sessionInfo kept; comparison below
- staged figures: figure staging not run

## Environment of the clean run

```
R version 4.6.0 (2026-04-24)
Platform: aarch64-apple-darwin23
Running under: macOS Sequoia 15.7.3

Matrix products: default
BLAS:   /Library/Frameworks/R.framework/Versions/4.6/Resources/lib/libRblas.0.dylib 
LAPACK: /Library/Frameworks/R.framework/Versions/4.6/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
[1] C.UTF-8/C.UTF-8/C.UTF-8/C/C.UTF-8/C.UTF-8

time zone: Asia/Tokyo
```

## Regenerated vs shipped outputs

```
                                    file                    status max_abs_diff
               analysis/j1_bootstrap.csv                 identical            0
               analysis/j1_by_cohort.csv                 identical            0
                  analysis/j1_decomp.txt                 identical            0
            analysis/j1_descriptives.csv                 identical            0
              analysis/j1_fig_checks.txt                 identical            0
                    analysis/j1_flow.csv                 identical            0
        analysis/j1_implicit_weights.csv                 identical            0
             analysis/j1_income_sens.csv                 identical            0
             analysis/j1_input_check.csv                 identical            0
 analysis/j1_measurement_calibration.csv                 identical            0
          analysis/j1_missing_shares.csv                 identical            0
                   analysis/j1_roles.csv                 identical            0
             analysis/j1_sessionInfo.txt non-numeric token differs           NA
                   analysis/j1_specs.csv                 identical            0
                 analysis/j1_support.csv                 identical            0
        analysis/j1_templates_output.txt                 identical            0
              analysis/j1_unlicensed.csv                 identical            0
                analysis/j1_validity.csv                 identical            0
       analysis/j1_world_diagnostics.csv                 identical            0

files compared: 19; identical: 18; numeric difference: 0 (max -); other: 1
```

## Figures (PNG) — reported separately; not part of the comparison above

The token-wise comparison above covers the CSV/TXT/MD outputs only; the PNGs and `j1_fig_provenance.txt` are set aside before it
(its file count therefore excludes them). The figure check is split into data inputs, drawing code and drawing environment:

```
PNG files (shipped analysis/synthetic_out/ vs regenerated in the clean copy):
  j1_fig_dag.png       shipped 222583a15216b5d3  regenerated 222583a15216b5d3  byte-identical
  j1_fig_specmap.png   shipped 7a2e4e2bd6c30f9b  regenerated 7a2e4e2bd6c30f9b  byte-identical
shipped PNGs, data inputs: drawn from the shipped CSVs (3 of 3 sha256)
shipped PNGs, drawing code (label text): drawn by the j1_fig_helpers.R of this snapshot
shipped PNGs listed in the provenance: yes
drawing environment: shipped R_4.6.0 aarch64-apple-darwin23 ragg_1.5.2 font=Hiragino_Sans | regenerated R_4.6.0 aarch64-apple-darwin23 ragg_1.5.2 font=Hiragino_Sans
Reading: the regenerated PNGs are drawn by the same code from the regenerated CSVs, which the token-wise table above compares with the shipped CSVs; when the data inputs and the drawing code agree, a byte difference comes from the drawing environment (R, graphics device, fonts). A hash difference alone is not taken as evidence of which of these differs. The regenerated PNGs are kept in figures_regen/ under the work directory printed at the start, for inspection.
```
