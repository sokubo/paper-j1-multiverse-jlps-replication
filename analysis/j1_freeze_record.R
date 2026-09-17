# j1_freeze_record.R — 正規利用者による固定版再実行の記録(知人査読第 3 回 R3-DC1)。
# 入力ファイルの識別(名前・サイズ・SHA-256; 個票の中身は出さない)、実行コードのチェックサム、環境、
# results/ の各出力の SHA-256、および本文 v0.9 に転記した数値と出力の照合を 1 組にして書き出す。
# Usage: Rscript j1_freeze_record.R <official .dta/.sav> <jlps_all_wide.rds> <results_dir> [<jp_combine_wide.R>]
#   例: Rscript j1_freeze_record.R ~/Documents/JLPS_data/raw/ZQ115...RQ102.dta ~/Documents/JLPS_data/work_jp/jlps_all_wide.rds ../results ../../jp_combine_wide.R
# 出力: <results_dir>/j1_freeze_record.txt, j1_freeze_record.csv(個票を含まない)。
suppressMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("Usage: Rscript j1_freeze_record.R <official .dta> <jlps_all_wide.rds> <results_dir> [<jp_combine_wide.R>]")
official <- args[1]; rds <- args[2]; resdir <- args[3]
script_dir <- { f <- grep("^--file=", commandArgs(), value = TRUE); if (length(f)) dirname(sub("^--file=", "", f[1])) else "." }
conv <- if (length(args) >= 4) args[4] else file.path(script_dir, "..", "..", "jp_combine_wide.R")
sha <- function(f) as.vector(sha_raw(f))
sha_raw <- function(f) {   # sha256 via openssl (R >= 4.5 has tools::sha256sum; the system tool works on macOS and Linux)
  if (!file.exists(f)) return(NA_character_)
  if (exists("sha256sum", asNamespace("tools"))) return(as.character(get("sha256sum", asNamespace("tools"))(f)))
  if (requireNamespace("openssl", quietly = TRUE)) return(paste(as.character(unclass(openssl::sha256(file(f)))), collapse = ""))
  r <- tryCatch(system2("shasum", c("-a", "256", shQuote(f)), stdout = TRUE), error = function(e) NULL)
  if (is.null(r) || !length(r)) r <- tryCatch(system2("sha256sum", shQuote(f), stdout = TRUE), error = function(e) NULL)
  if (is.null(r) || !length(r)) return("(no sha256 tool found)"); sub(" .*", "", r[1])
}
out <- character(0); say <- function(...) out <<- c(out, sprintf(...))
rec <- list()
say("J1 freeze record  %s", format(Sys.time(), "%Y-%m-%d %H:%M %Z"))
say("")
## 1. input identity (no content)
say("== 1. input files (identity only) ==")
for (x in list(c("official", official), c("analysis_rds", rds))) {
  f <- x[2]; ok <- file.exists(f)
  say("  %-12s %s  size=%s  sha256=%s", x[1], basename(f), if (ok) format(file.size(f), big.mark = ",") else "MISSING", if (ok) sha(f) else "MISSING")
  rec[[length(rec) + 1]] <- data.table(section = "input", item = x[1], value = basename(f), sha256 = sha(f))
}
if (file.exists(rds)) { d <- readRDS(rds); say("  analysis_rds rows=%d cols=%d unique panelid=%d", nrow(d), ncol(d), uniqueN(d$panelid))
  rec[[length(rec) + 1]] <- data.table(section = "input", item = "analysis_rds_dims", value = sprintf("%d x %d; unique panelid %d", nrow(d), ncol(d), uniqueN(d$panelid)), sha256 = NA_character_); rm(d) }
## 2. code checksums
say(""); say("== 2. code (sha256) ==")
codes <- c(list.files(script_dir, pattern = "^j1_.*\\.R$", full.names = TRUE), if (file.exists(conv)) conv)
codes <- codes[!grepl("_backup\\.R$", codes)]
for (f in sort(codes)) { say("  %-32s %s", basename(f), sha(f)); rec[[length(rec) + 1]] <- data.table(section = "code", item = basename(f), value = NA_character_, sha256 = sha(f)) }
## 3. environment
say(""); say("== 3. environment ==")
pk <- function(p) if (requireNamespace(p, quietly = TRUE)) as.character(packageVersion(p)) else "not installed"
env <- c(R = R.version.string, platform = R.version$platform, os = paste(Sys.info()[c("sysname", "release")], collapse = " "),
         dagmv = pk("dagmv"), data.table = pk("data.table"), haven = pk("haven"), locale = Sys.getlocale("LC_CTYPE"))
for (k in names(env)) { say("  %-10s %s", k, env[[k]]); rec[[length(rec) + 1]] <- data.table(section = "env", item = k, value = env[[k]], sha256 = NA_character_) }
## 4. outputs
say(""); say("== 4. outputs in %s (sha256) ==", resdir)
for (f in sort(list.files(resdir, full.names = TRUE))) { if (grepl("j1_freeze_record", f)) next
  say("  %-36s %s", basename(f), sha(f)); rec[[length(rec) + 1]] <- data.table(section = "output", item = basename(f), value = NA_character_, sha256 = sha(f)) }
## 5. manuscript (v0.9) numbers vs outputs
say(""); say("== 5. manuscript v0.9 numbers vs outputs (rounded to the printed precision) ==")
rd <- function(p) fread(file.path(resdir, p))
chk <- list(); add <- function(label, manuscript, value, digits) chk[[length(chk) + 1]] <<- data.table(label = label, manuscript = manuscript, output = round(value, digits), match = isTRUE(all.equal(round(value, digits), manuscript)))
tryCatch({
  u <- rd("j1_unlicensed.csv"); sp <- rd("j1_specs.csv"); bo <- rd("j1_bootstrap.csv"); bc <- rd("j1_by_cohort.csv"); fl <- rd("j1_flow.csv")
  mc <- rd("j1_measurement_calibration.csv"); su <- rd("j1_support.csv"); is <- rd("j1_income_sens.csv"); ms <- rd("j1_missing_shares.csv")
  fc <- readLines(file.path(resdir, "j1_fig_checks.txt"))
  add("naive mean", 0.117, u$naive_mean, 3); add("naive SD", 0.053, u$naive_sd, 3); add("naive sig rate", 0.97, u$naive_sig_rate, 2)
  add("naive min", 0.037, u$naive_min, 3); add("naive max", 0.245, u$naive_max, 3)
  add("unlicensed mean", 0.104, u$unlicensed_mean, 3); add("unlicensed max", 0.169, max(sp$estimate[sp$licensed_by == "none"]), 3)
  add("W1/W2 value (grades)", 0.168, sp$estimate[sp$ctrl == "grades"], 3); add("W1/W2 SE", 0.023, sp$se[sp$ctrl == "grades"], 3)
  add("W3/W4 value (none)", 0.245, sp$estimate[sp$ctrl == "(none)"], 3); add("W3/W4 SE", 0.021, sp$se[sp$ctrl == "(none)"], 3)
  add("all three mediators controlled", 0.061, sp$estimate[sp$ctrl == "occ;firm;regular"], 3)
  b1 <- bo[sample == "pooled_25_45" & quantity == "delta_W34_minus_W12"]
  add("contrast W34-W12", 0.077, b1$point, 3); add("contrast bootstrap SE", 0.011, b1$se, 3); add("contrast q025", 0.056, b1$q025, 3); add("contrast q975", 0.100, b1$q975, 3)
  add("married effect (no grades) < 0.0001 (1 = yes)", 1, as.numeric(abs(bo[sample == "pooled_25_45" & quantity == "delta_married_noGrades"]$point) < 1e-4), 0)
  add("rho", 1.00, u$share_between, 2)
  add("r2 = Corr^2(E,R)", 0.186, mc$r2_obs[1], 3)
  for (l in c(1, .9, .8, .65)) add(sprintf("tau at lambda=%g", l), c(`1` = 0.168, `0.9` = 0.157, `0.8` = 0.143, `0.65` = 0.110)[[as.character(l)]], mc$tau_two_parameter[abs(mc$lambda - l) < 1e-9], 3)
  w12 <- function(co) mean(bc[cohort == co & grepl("^W[12]", dag)]$mean); w34 <- function(co) mean(bc[cohort == co & grepl("^W[34]", dag)]$mean)
  add("2007 W12", 0.185, w12("2007"), 3); add("2007 W34", 0.255, w34("2007"), 3); add("2011 W12", 0.278, w12("2011"), 3); add("2011 W34", 0.346, w34("2011"), 3)
  add("2019 W12", 0.036, w12("2019"), 3); add("2019 W34", 0.141, w34("2019"), 3)
  fa <- function(st) fl[cohort == "all" & stage == st]$n
  add("flow: first-wave respondents", 8146, fa("0_first_wave_respondents"), 0); add("flow: 25-45", 6619, fa("1_age25_45"), 0); add("flow: employees", 5072, fa("2_employee"), 0)
  add("flow: positive income", 4751, fa("3_pos_income"), 0); add("flow: licensed vars complete", 4180, fa("4_complete_licensed_vars"), 0); add("flow: all vars complete", 3832, fa("5_complete_all_vars"), 0)
  add("univ share in analysis sample", 0.451, fl[cohort == "all" & stage == "5_complete_all_vars"]$univ_share, 3)
  add("missing share peduc", 0.101, ms[cohort == "all"]$peduc, 3); add("missing share firm", 0.089, ms[cohort == "all"]$firm, 3)
  g <- function(txt) as.numeric(sub(".*: ", "", fc[grepl(txt, fc, fixed = TRUE)]))
  add("fig2: CIs excluding 0.168", 20, g("excludes the W1/W2 value"), 0); add("fig2: CIs excluding 0.245", 28, g("excludes the W3/W4 value"), 0); add("fig2: CIs excluding naive mean", 12, g("excludes the naive mean"), 0)
  add("note2 2007 grades", 0.115, su[analysis == "common_support_25_32" & cohort == "2007" & ctrl == "grades"]$estimate, 3); add("note2 2007 none", 0.182, su[analysis == "common_support_25_32" & cohort == "2007" & ctrl == "(none)"]$estimate, 3)
  add("note2 2011 grades", 0.208, su[analysis == "common_support_25_32" & cohort == "2011" & ctrl == "grades"]$estimate, 3); add("note2 2011 none", 0.255, su[analysis == "common_support_25_32" & cohort == "2011" & ctrl == "(none)"]$estimate, 3)
  add("note2 pooled grades", 0.087, su[analysis == "common_support_25_32" & cohort == "all" & ctrl == "grades"]$estimate, 3); add("note2 pooled none", 0.173, su[analysis == "common_support_25_32" & cohort == "all" & ctrl == "(none)"]$estimate, 3)
  add("note2 pooled 25-32 contrast SE", 0.014, bo[sample == "pooled_25_32" & quantity == "delta_none_minus_grades"]$se, 3)
  add("note3 max sample grades", 0.184, su[analysis == "max_sample_licensed_vars_complete" & ctrl == "grades"]$estimate, 3); add("note3 max sample none", 0.262, su[analysis == "max_sample_licensed_vars_complete" & ctrl == "(none)"]$estimate, 3)
  add("note3 excl. working students grades", 0.175, su[analysis == "main_sample_excl_working_students" & ctrl == "grades"]$estimate, 3); add("note3 excl. working students none", 0.253, su[analysis == "main_sample_excl_working_students" & ctrl == "(none)"]$estimate, 3)
  add("note3 midpoints grades", 0.169, su[analysis == "main_sample_income_midpoints" & ctrl == "grades"]$estimate, 3); add("note3 midpoints none", 0.246, su[analysis == "main_sample_income_midpoints" & ctrl == "(none)"]$estimate, 3)
  add("note3 top-band gap 2250", 0.0768, is[variant == "memo_2250"]$gap_none_minus_grades[1], 4); add("note3 top-band gap 3750", 0.0766, is[variant == "x1.5"]$gap_none_minus_grades[1], 4)
  ## v4 / R3-O1: note 3, categorical coding of the retrospective grade (manuscript v0.9).
  ## The manuscript states the difference as categorical - linear (+0.0005); j1_bootstrap.csv stores
  ## linear - categorical, so the sign of the point estimate and of the interval bounds is flipped here.
  if (any(su$analysis == "main_sample_grades_categorical") &&
      nrow(bo[sample == "pooled_25_45" & quantity == "delta_contrast_linear_minus_categorical"]) == 1L) {
    dc <- bo[sample == "pooled_25_45" & quantity == "delta_contrast_linear_minus_categorical"]
    add("note3 categorical contrast", 0.0772, bo[sample == "pooled_25_45_grades_categorical" & quantity == "delta_none_minus_grades"]$point, 4)
    add("note3 linear contrast (for comparison)", 0.0767, bo[sample == "pooled_25_45" & quantity == "delta_none_minus_grades"]$point, 4)
    add("note3 categorical - linear", 0.0005, -dc$point, 4)
    add("note3 paired SE", 0.002, dc$se, 3)
    add("note3 paired interval, lower", -0.004, -dc$q975, 3)
    add("note3 paired interval, upper", 0.005, -dc$q025, 3) }
}, error = function(e) say("  !! comparison could not be completed: %s", conditionMessage(e)))
chk <- rbindlist(chk)
if (nrow(chk)) { for (i in seq_len(nrow(chk))) say("  %-58s manuscript=%-8s output=%-8s %s", chk$label[i], format(chk$manuscript[i]), format(chk$output[i]), if (is.na(chk$manuscript[i])) "(new in v4)" else if (chk$match[i]) "ok" else "!! MISMATCH")
  say(""); say("  matched %d of %d transcribed numbers%s", sum(chk$match, na.rm = TRUE), sum(!is.na(chk$manuscript)), if (any(!chk$match & !is.na(chk$manuscript))) "  !! some mismatch — check the manuscript" else "") }
writeLines(out, file.path(resdir, "j1_freeze_record.txt"))
fwrite(rbind(rbindlist(rec), if (nrow(chk)) chk[, .(section = "manuscript_check", item = label, value = paste0("manuscript=", manuscript, "; output=", output, "; match=", match), sha256 = NA_character_)]), file.path(resdir, "j1_freeze_record.csv"))
cat(out, sep = "\n"); cat("\nwritten:", file.path(resdir, "j1_freeze_record.txt"), "\n")
