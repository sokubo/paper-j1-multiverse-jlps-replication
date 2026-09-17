## j1_convert_input.R -- 公式提供版(統合 Stata ファイル)を分析用 RDS に変換する(ローカル専用; 個票はプロジェクト外に保存)。
## paper/jp/jp_combine_wide.R の写し(2026-09-17, 知人査読第 3 回 R3-DC1)。差分が出ないよう内容は同一に保つ。
## Usage: Rscript j1_convert_input.R <out.rds> <統合 .dta>
suppressPackageStartupMessages({ library(haven); library(data.table) })
a <- commandArgs(trailingOnly = TRUE); out <- a[1]; files <- a[-1]
stopifnot(length(files) >= 1)
read_any <- function(f) switch(tolower(tools::file_ext(f)), dta = read_dta(f), sav = read_sav(f), rds = readRDS(f), stop("unsupported: ", f))
lst <- lapply(files, function(f) {
  d <- as.data.table(read_any(f)); setnames(d, tolower(names(d)))
  d <- d[, lapply(.SD, function(x) if (inherits(x, "haven_labelled")) as.numeric(x) else x)]
  fl <- tolower(basename(f))
  ## 統合ファイル(ZQ...で始まる名前)は cohort を NA にする(下流 j3 が初回回答波から推定する)
  d[, cohort := if (grepl("^zq", fl)) NA_integer_ else if (grepl("add2|add_2|2011", fl)) 2011L else if (grepl("refresh|re_|2019", fl)) 2019L else 2007L]
  d[, entry  := if (is.na(cohort[1])) NA_integer_ else if (cohort[1] == 2011L) 5L else if (cohort[1] == 2019L) 13L else 1L]
  d[, source_file := basename(f)]
  cat(sprintf("  %-40s rows=%6d cols=%5d cohort=%s\n", basename(f), nrow(d), ncol(d), ifelse(is.na(d$cohort[1]), "(統合: 後で推定)", d$cohort[1]))); d
})
all <- rbindlist(lst, fill = TRUE, use.names = TRUE)
if (!"panelid" %in% names(all)) stop("panelid 列が見つかりません(列名を確認)")
cat(sprintf("combined: rows=%d cols=%d unique panelid=%d\n", nrow(all), ncol(all), uniqueN(all$panelid)))
saveRDS(all, out); cat("written:", out, "\n")
