# Release check — paper-j1-multiverse-jlps-replication

Date: 2026-09-17T14:32:28Z. Snapshot downloaded anonymously (no credentials, no gh CLI) from `https://codeload.github.com/sokubo/paper-j1-multiverse-jlps-replication/tar.gz/main`.

- ref: `main`; commit: `fa0eb1a24ac9e6380705a58979d13f2cd7a43df1`
- archive SHA-256: `ae241365e733e74fc31ad460b7309a7be161ba15d77283d5f14abfb19444aa2b`
- files in snapshot (excluding FILE_MANIFEST.txt and RELEASE_CHECK*): 36; listed in FILE_MANIFEST.txt: 36; missing from snapshot: 0; not listed in manifest: 0
- clean run: documented sequence executed in a clean copy with shipped outputs set aside (109s); log and sessionInfo kept; comparison below
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
