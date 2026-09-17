# j1_jlps_application.R — J1『理論と方法』の実証節: JLPS 三標本の初回調査(2007 w1 / 2011 w5 / 2019 w13)を
# プールした横断データで、大学在籍(最終在籍校が大学・大学院)の所得係数の多元宇宙を候補 DAG で規律づける。
# RUNS ONLY ON THE LICENSED LOCAL MACHINE(案A)。個票は書き出さず、N<10 抑制済みの集計値と図のみ results/ に出力する。
# Usage: Rscript j1_jlps_application.R <jlps_all_wide.rds> <results_dir>
# v2(2026-09-05 知人査読対応): W5(混合測定世界)、個人ブートストラップ、標本フロー、共通支持・最大標本、上端区分感度、投入マトリクス付き図。
# v3(2026-09-17 知人査読第 2 回 DC1/DC2 対応): 認可対応表 j1_validity.csv、所得の区分代表値(選択肢の「〜くらい」の値)と区間中点の両方、
#    働く学生(wrktype 12)を除いた感度、ブートストラップの成功反復数と区間方式の記録、図 2 の区間比較の出力値による確認 j1_fig_checks.txt、
#    測定感度の較正量(統制変数で残差化した E と R の相関二乗)j1_measurement_calibration.csv、ウェイト変数の有無(名前のみ)、sessionInfo。
#    2019 コホートの年齢は「調査年 − 出生年」で 21–32(= 1987–1998 年生まれ; 石田ほか 2020 の「2019 年時点で 20–31 歳」に対応)。
# v4(2026-09-17 知人査読第 3 回 R3-DC1/m2/O1 対応): 入力検査(個人 ID の一意性、標本割当の排他性、使用列の値域)、
#    ブートストラップの n_success を標本・統計量ごとの有限反復数に(旧 v3 はプール 32 仕様の成功数を全行に複写)、
#    成績を 4 自由度のカテゴリ変数にした認可 4 仕様の感度と対応のあるブートストラップ(R3-O1; 中澤 2022 p. 496 の等間隔性への注意)。
#    推定の定義・乱数種・既存の出力列は不変(v3 = j1_jlps_application_v3_backup.R)。
suppressMessages({ library(data.table); library(dagmv) })
args <- commandArgs(trailingOnly = TRUE)
infile <- if (length(args) >= 1) args[1] else "synthetic/j1_synth_wide.rds"
outdir <- if (length(args) >= 2) args[2] else "synthetic_out"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
MIN_CELL <- 10
B_BOOT <- if (nzchar(Sys.getenv("J1_B"))) as.integer(Sys.getenv("J1_B")) else 500; SEED <- 20260905
script_dir <- { f <- grep("^--file=", commandArgs(), value = TRUE); if (length(f)) dirname(sub("^--file=", "", f[1])) else "." }
source(file.path(script_dir, "j1_fig_helpers.R"))
raw <- as.data.table(readRDS(infile)); setnames(raw, tolower(names(raw)))
raw <- raw[, lapply(.SD, function(x) if (inherits(x, "haven_labelled")) as.numeric(x) else x)]
has <- function(v) v %in% names(raw)
g <- function(v, na = c(88, 99, 888, 999)) { if (!has(v)) return(rep(NA_real_, nrow(raw))); x <- as.numeric(raw[[v]]); x[x %in% na] <- NA; x }
ok <- function(x) !is.na(x)
supp <- function(n) ifelse(n < MIN_CELL, NA_integer_, n)   # N<10 秘匿

## ---- variable-existence diagnostics (names only; nothing person-level is printed) ----
need <- c(w1  = "zq23a zq17 zq23c zq23d zq50 zq47a jc_1 jc_2 jc_6 zq03",
          w5  = "dq69a dq61 dq69c dq69d dq43 dq35a dq03_1 dq03_2 dq03_7 dq02",
          w13 = "lq72a lq65 lq72b lq72c lq44 lq44re_2 lq37a lq03_1 lq03_2 lq03_7 lq02",
          fixed = "panelid sex ybirth")
for (k in names(need)) {
  vs <- strsplit(need[[k]], " ")[[1]]; miss <- vs[!vs %in% names(raw)]
  if (length(miss)) {
    cat(sprintf("!! %s: not found: %s\n", k, paste(miss, collapse = " ")))
    for (m in miss) { cand <- grep(paste0("^", substr(m, 1, min(nchar(m), 4))), names(raw), value = TRUE)
      if (length(cand)) cat(sprintf("     candidates for %s: %s\n", m, paste(head(cand, 12), collapse = " "))) }
  } else cat(sprintf("   %s: all variables found\n", k))
}
if (!all(c("panelid", "sex", "ybirth") %in% names(raw))) stop("panelid/sex/ybirth missing")

## ---- cohort = first wave with a core marker answered (2007: w1 / 2011: w5 / 2019: w13) ----
m07 <- ok(g("zq50")) | ok(g("zq03")) | ok(g("zq23a"))
m11 <- !m07 & (ok(g("dq43")) | ok(g("dq02")) | ok(g("dq69a")))
m19 <- !m07 & !m11 & (ok(g("lq44re_2")) | ok(g("lq02")) | ok(g("lq72a")))
cat(sprintf("cohorts: 2007=%d  2011=%d  2019=%d  (unassigned %d)\n", sum(m07), sum(m11), sum(m19), sum(!(m07 | m11 | m19))))
## ---- input checks (v4, R3-DC1): unique person id, exclusive sample assignment, value ranges of the columns used (aggregates only) ----
stopifnot("panelid must be unique" = !anyDuplicated(raw$panelid))
stopifnot("sample assignment must be exclusive" = all(m07 + m11 + m19 <= 1))
rng <- function(v) { x <- suppressWarnings(as.numeric(raw[[v]])); x <- x[!is.na(x)]; if (!length(x)) "(all NA)" else sprintf("%g..%g (n=%d)", min(x), max(x), length(x)) }
chk_cols <- c("zq23a", "dq69a", "lq72a", "zq17", "dq61", "lq65", "zq47a", "dq35a", "lq37a", "jc_1", "dq03_1", "lq03_1", "sex", "ybirth")
cat("input value ranges (min..max, non-missing n):\n"); for (v in chk_cols) if (v %in% names(raw)) cat(sprintf("   %-9s %s\n", v, rng(v)))
input_check <- data.table(check = c("rows", "unique_panelid", "cohort_2007", "cohort_2011", "cohort_2019", "unassigned", "exclusive_assignment"),
                          value = c(nrow(raw), uniqueN(raw$panelid), sum(m07), sum(m11), sum(m19), sum(!(m07 | m11 | m19)), as.integer(all(m07 + m11 + m19 <= 1))))
fwrite(input_check, file.path(outdir, "j1_input_check.csv"))

## ---- first-wave variables per cohort (same coding: public-version labels PY160) ----
## 所得 13 区分 → 万円。選択肢は「100万円くらい（75～150万円未満）」の形で代表値と区間を併記する(j1_check_source.R のログ参照)。
## band_label = 選択肢に示された代表値(本文の主分析; v0.6 までの本文は「中点」と書いていたが正しくは区分代表値)、band_midpt = 区間の中点。
## 区分 1 = なし(0 → 所得正の条件で除外)、2 = 25 万円未満(代表値なし → 12.5)、13 = 2,250 万円以上(開区間 → 2,500)、14 = わからない → 欠測。
band_label <- c(0, 12.5, 50, 100, 200, 300, 400, 500, 700, 1000, 1500, 2000, 2500)
band_midpt <- c(0, 12.5, 50, 112.5, 200, 300, 400, 525, 725, 1050, 1500, 2000, 2500)
band_mid <- band_label
TOP_MID <- 2500
pick <- function(sel, educ, grade, pa, ma, mar, inc, wt, occ, firm, year, w1 = FALSE) {
  d <- data.table(panelid = raw$panelid[sel], sex = as.numeric(raw$sex[sel]), ybirth = as.numeric(raw$ybirth[sel]), year = year)
  E <- g(educ)[sel]; d[, educ := ifelse(E %in% 1:6, E, NA)]
  G <- g(grade)[sel]; d[, grades := ifelse(G %in% 1:5, 6 - G, NA)]              # 1=上の方 … 5=下の方 → 高いほど良い
  P <- g(pa)[sel]; M <- g(ma)[sel]; P[!P %in% 1:6] <- NA; M[!M %in% 1:6] <- NA
  d[, peduc := pmax(P, M, na.rm = TRUE)]; d[is.infinite(peduc), peduc := NA]        # 父母の最終学校の高い方
  R <- g(mar)[sel]
  d[, married := if (w1) as.integer(R == 2) else as.integer(R == 1)]              # w1: 1=未婚 2=既婚 3=死別 4=離別; w5/w13: 1=既婚
  d[!R %in% 1:4, married := NA]
  I <- g(inc)[sel]; d[, inc_band := ifelse(I %in% 1:13, I, NA)]; d[, inc_man := ifelse(!is.na(inc_band), band_mid[pmin(pmax(inc_band, 1), 13)], NA)]
  d[, inc_man_midpt := ifelse(!is.na(inc_band), band_midpt[pmin(pmax(inc_band, 1), 13)], NA)]
  W <- g(wt)[sel]; d[, wrktype := ifelse(W %in% 1:12, W, NA)]
  O <- g(occ)[sel]; d[, occ := ifelse(O %in% c(1:8, 10), O, NA)]                  # 9 = わからない
  F <- g(firm)[sel]; d[, firm := ifelse(F %in% 1:9, F, NA)]                       # 10 = わからない
  d
}
d07 <- pick(m07, "zq23a", "zq17", "zq23c", "zq23d", "zq50", "zq47a", "jc_1", "jc_2", "jc_6", 2007, w1 = TRUE)
d11 <- pick(m11, "dq69a", "dq61", "dq69c", "dq69d", "dq43", "dq35a", "dq03_1", "dq03_2", "dq03_7", 2011)
d19 <- pick(m19, "lq72a", "lq65", "lq72b", "lq72c", if (has("lq44re_2")) "lq44re_2" else "lq44", "lq37a", "lq03_1", "lq03_2", "lq03_7", 2019)
if (has("lq44re_2") && has("lq44")) { R2 <- g("lq44")[m19]; d19[is.na(married) & R2 %in% 1:4, married := as.integer(R2 == 1)] }
dd <- rbindlist(list(d07, d11, d19))
dd[, cohort := factor(year)]; dd[, age := year - ybirth]; dd[, female := as.integer(sex == 2)]
dd[, univ := as.integer(educ >= 5)]                                              # 大学・大学院
dd[, regular := as.integer(wrktype == 2)]
dd[, linc := ifelse(!is.na(inc_man) & inc_man > 0, log(inc_man), NA_real_)]
dd[, linc_midpt := ifelse(!is.na(inc_man_midpt) & inc_man_midpt > 0, log(inc_man_midpt), NA_real_)]
## weight variables in the delivered file (names only): the analysis is unweighted
wt_names <- grep("weight|^wt|^w_|ウェイト|重み", names(raw), value = TRUE, ignore.case = TRUE)
cat("weight-like variable names in the delivered file:", if (length(wt_names)) paste(wt_names, collapse = " ") else "(none found)", "\n")

## ---- (f) design notes (printed for the log; nothing person-level) ----
cat("design notes:\n",
    "  age = survey year - birth year (age reached in the survey year; birth month not used); analysis ages 25-45\n",
    "  treatment = last school attended is university/graduate school (educ 5-6; completion, enrolment and dropout are not distinguished by the item) vs all else\n",
    "  outcome = log(representative value printed in the income option label, 13 bands; band 2 -> 12.5; top band (2,250+) assigned", TOP_MID, "man yen); interval midpoints as a sensitivity\n",
    "  nominal yen; survey-year (cohort) dummies absorb any year-specific deflator exactly because the outcome is in logs\n",
    "  SE = HC1 (heteroskedasticity-robust, no clustering): PSU / strata identifiers are not in the delivered file; the analysis is unweighted\n")

## ---- (c) sample flow: all first-wave respondents -> 25-45 -> employees -> positive income -> complete cases, by cohort ----
LIC_VARS <- c("univ", "grades", "peduc", "married", "age", "female")
ALL_VARS <- c(LIC_VARS, "occ", "firm", "regular")
st0 <- dd
st1 <- dd[age >= 25 & age <= 45]
st2 <- st1[wrktype %in% c(2, 3, 4, 5, 12)]                                       # 被用者(正社員・パート等・派遣・請負・学生非正規)
st3 <- st2[!is.na(linc)]                                                         # 正の所得を報告
st4b <- st3[complete.cases(st3[, ..LIC_VARS])]                                   # 認可仕様に必要な変数のみ完全(最大標本)
st4 <- st3[complete.cases(st3[, ..ALL_VARS])]                                    # 全 5 争点変数まで完全(= 分析標本 d)
flow_row <- function(x, stage) x[, .(stage = stage, n = .N, univ_share = round(mean(univ, na.rm = TRUE), 3), female_share = round(mean(female, na.rm = TRUE), 3),
                                     age_min = min(age, na.rm = TRUE), age_max = max(age, na.rm = TRUE), mean_age = round(mean(age, na.rm = TRUE), 1)), by = cohort]
flow_all <- function(x, stage) { r <- flow_row(x, stage); a <- flow_row(copy(x)[, cohort := factor("all")], stage); rbind(r, a) }
fl <- rbindlist(list(flow_all(st0, "0_first_wave_respondents"), flow_all(st1, "1_age25_45"), flow_all(st2, "2_employee"), flow_all(st3, "3_pos_income"),
                     flow_all(st4b, "4_complete_licensed_vars"), flow_all(st4, "5_complete_all_vars")))
fl[n < MIN_CELL, setdiff(names(fl), c("cohort", "stage")) := NA]; fl[, n := supp(n)]
setorder(fl, stage, cohort); fwrite(fl, file.path(outdir, "j1_flow.csv")); cat("\nsample flow (by cohort):\n"); print(fl)

## ---- analysis sample ----
d <- copy(st3)
cat("\nemployees 25-45 with income:", nrow(d), "\n")
cat("  missing shares (all): "); print(round(sapply(d[, .(univ, grades, peduc, married, occ, firm, regular)], function(x) mean(is.na(x))), 3))
cat("  missing shares by cohort:\n"); print(d[, lapply(.SD, function(x) round(mean(is.na(x)), 3)), by = cohort, .SDcols = c("univ", "grades", "peduc", "married", "occ", "firm", "regular")])
miss <- rbind(cbind(cohort = "all", d[, lapply(.SD, function(x) round(mean(is.na(x)), 3)), .SDcols = c("univ", "grades", "peduc", "married", "occ", "firm", "regular")]),
              d[, lapply(.SD, function(x) round(mean(is.na(x)), 3)), by = cohort, .SDcols = c("univ", "grades", "peduc", "married", "occ", "firm", "regular")])
fwrite(miss, file.path(outdir, "j1_missing_shares.csv"))   # 本文 §7.1 の「親学歴(欠測 10%)・企業規模(同 9%)」の出典
d <- d[complete.cases(d[, ..ALL_VARS])]
d[, `:=`(occ_f = factor(occ), firm_f = factor(firm), peduc_f = factor(peduc), age2 = age^2)]
cat("analysis rows:", nrow(d), " univ share:", round(mean(d$univ), 3), "\n")
if (nrow(d) < 300) stop("too few rows; check variable names")

## suppressed descriptives
desc <- d[, .(n = .N, univ_share = round(mean(univ), 3), female_share = round(mean(female), 3), mean_age = round(mean(age), 1),
              mean_linc_univ = round(mean(linc[univ == 1]), 3), mean_linc_nonuniv = round(mean(linc[univ == 0]), 3),
              married_share = round(mean(married), 3), regular_share = round(mean(regular), 3)), by = cohort][order(cohort)]
desc <- rbind(desc, d[, .(cohort = factor("all"), n = .N, univ_share = round(mean(univ), 3), female_share = round(mean(female), 3), mean_age = round(mean(age), 1),
              mean_linc_univ = round(mean(linc[univ == 1]), 3), mean_linc_nonuniv = round(mean(linc[univ == 0]), 3),
              married_share = round(mean(married), 3), regular_share = round(mean(regular), 3))])
desc[n < MIN_CELL, setdiff(names(desc), "cohort") := NA]
fwrite(desc, file.path(outdir, "j1_descriptives.csv")); print(desc)

## ---- candidate DAGs ----
## uncontested: peduc (親学歴), age, female, cohort → educ and inc. Contested:
##   grades  — (a) 中学成績 = 教育に先行する能力・意欲の交絡変数(required; R = G* を仮定) / (b) 回顧報告は到達した学歴・所得に引きずられる子孫(forbidden)
##             (c) W5 混合: 真の成績 G*(潜在)が進学と所得の両方に効き、観測される回顧報告 R(grades)は G* と到達地位の両方の子孫 → 妥当集合なし
##   married — (a) 学歴と所得の双方の結果(コライダー: forbidden) / (b) 所得に影響する精度変数(optional)
##   occ, firm, regular — 教育→所得の媒介変数(すべての世界で forbidden。素朴な多元宇宙はこれらを統制した仕様を混ぜる)
base <- "peduc -> educ ; peduc -> inc ; age -> educ ; age -> inc ; female -> educ ; female -> inc ; cohort -> educ ; cohort -> inc ; educ -> inc ;
         educ -> occ ; occ -> inc ; educ -> firm ; firm -> inc ; educ -> regular ; regular -> inc ; peduc -> occ ; peduc -> firm"
gr_conf <- "grades -> educ ; grades -> inc ; peduc -> grades"                                        # W1/W2: R ≡ G*
gr_desc <- "gstar [latent] ; gstar -> educ ; gstar -> grades ; peduc -> gstar ; educ -> grades ; inc -> grades"   # W3/W4: G*→educ のみ、R は到達地位の子孫
gr_mix  <- "gstar [latent] ; gstar -> educ ; gstar -> inc ; gstar -> grades ; peduc -> gstar ; educ -> grades ; inc -> grades"   # W5: 混合
ma_coll <- "educ -> married ; inc -> married"
ma_prec <- "married -> inc"
mk <- function(...) paste("dag {", paste(c(base, ...), collapse = " ; "), "}")
dags <- list("W1 成績=交絡(R=G*)・婚姻=コライダー" = mk(gr_conf, ma_coll), "W2 成績=交絡(R=G*)・婚姻=精度変数" = mk(gr_conf, ma_prec),
             "W3 成績=回顧の子孫・婚姻=コライダー" = mk(gr_desc, ma_coll), "W4 成績=回顧の子孫・婚姻=精度変数" = mk(gr_desc, ma_prec),
             "W5 成績=混合(G*潜在)・婚姻=コライダー" = mk(gr_mix, ma_coll))
contested <- c("occ", "firm", "regular", "married", "grades"); baselines <- c("peduc", "age", "female", "cohort")
J <- length(contested); ids <- 0:(2^J - 1)
subs <- lapply(ids, function(i) contested[bitwAnd(i, 2^(seq_len(J) - 1)) > 0])
lab <- vapply(subs, function(s) if (length(s)) paste(s, collapse = ";") else "(none)", "")
validity <- vapply(dags, function(dg) { gg <- dag_parse(dg); vapply(subs, function(s) adjustment_valid(gg, c(baselines, s), "educ", "inc"), TRUE) }, logical(length(subs)))
rownames(validity) <- lab
## (a) role table; a world with no admissible set is recorded as 'not identified' instead of stopping
roles <- do.call(rbind, lapply(names(dags), function(nm) {
  r <- tryCatch(mv_classify(dag_parse(dags[[nm]]), c(baselines, contested), "educ", "inc"),
                error = function(e) data.frame(control = c(baselines, contested), role = "not identified (no admissible set)"))
  r <- r[r$control %in% contested, ]; r$dag <- nm; r }))
fwrite(roles, file.path(outdir, "j1_roles.csv")); print(validity)
cat("\nadmissible specifications per world:"); print(colSums(validity))
for (nm in names(dags)) if (sum(validity[, nm]) == 0) cat(sprintf("  >> %s: NOT IDENTIFIED BY ADJUSTMENT (no subset of the candidate pool is admissible)\n", nm))
## diagnostic worlds (printed + csv): the identification of W1/W2 needs R ≡ G*; an error-only proxy is already not identified;
## a world with G*→educ only and an uncontaminated report makes grades optional (both (none) and grades admissible → the two coefficients should coincide)
diag_worlds <- list("W5' 成績=混合・婚姻=精度変数" = mk(gr_mix, ma_prec),
                    "D1 成績=交絡, R=G*+誤差(汚染なし)" = mk("gstar [latent] ; gstar -> educ ; gstar -> inc ; gstar -> grades ; peduc -> gstar", ma_prec),
                    "D2 成績=無関係(G*→educ のみ, 汚染なし)" = mk("gstar [latent] ; gstar -> educ ; gstar -> grades ; peduc -> gstar", ma_prec))
dw <- rbindlist(lapply(names(diag_worlds), function(nm) { gg <- dag_parse(diag_worlds[[nm]]); v <- vapply(subs, function(s) adjustment_valid(gg, c(baselines, s), "educ", "inc"), TRUE)
  data.table(world = nm, n_valid = sum(v), valid_sets = paste(lab[v], collapse = " | ")) }))
fwrite(dw, file.path(outdir, "j1_world_diagnostics.csv")); cat("\ndiagnostic worlds:\n"); print(dw)

## ---- fit the 32 specifications (OLS, HC1 standard errors) ----
term <- function(v) switch(v, occ = "occ_f", firm = "firm_f", regular = "regular", married = "married", grades = "grades",
                           peduc = "peduc_f", age = "age + age2", female = "female", cohort = "cohort")
hc1 <- function(m, coefname) { X <- model.matrix(m); ok <- !is.na(coef(m)); X <- X[, ok, drop = FALSE]; u <- resid(m)
  br <- solve(crossprod(X)); meat <- crossprod(X * u); V <- br %*% meat %*% br * nrow(X) / (nrow(X) - ncol(X))
  j <- which(colnames(X) == coefname); c(coef(m)[coefname], sqrt(V[j, j])) }
fit_spec <- function(s, data = d) {
  bl <- if (length(unique(data$cohort)) > 1) baselines else setdiff(baselines, "cohort")   # single-cohort fits drop the cohort dummy
  rhs <- c("univ", sapply(c(bl, s), term))
  m <- lm(as.formula(paste("linc ~", paste(rhs, collapse = "+"))), data)
  cs <- hc1(m, "univ"); c(cs[1], cs[2], 2 * pnorm(-abs(cs[1] / cs[2])))
}
res <- t(sapply(subs, fit_spec))
fits <- data.frame(spec_id = seq_along(subs), ctrl = lab, estimate = res[, 1], se = res[, 2], p = res[, 3])
fits$licensed_by <- apply(validity, 1, function(v) if (any(v)) paste(substr(names(dags)[v], 1, 2), collapse = ",") else "none")
fwrite(fits, file.path(outdir, "j1_specs.csv"))
## admissibility table: 32 specifications x 5 candidate worlds (TRUE = the set is valid under the generalized adjustment criterion)
vt <- data.table(spec_id = seq_along(subs), ctrl = lab); for (w in colnames(validity)) vt[[substr(w, 1, 2)]] <- validity[, w]
fwrite(vt, file.path(outdir, "j1_validity.csv"))

## ---- decomposition (dagmv) and unlicensed share; W5 enters with n_specs = 0 and is excluded from rho (weights renormalised) ----
dec <- mv_decompose(cbind(fits, validity[fits$ctrl, , drop = FALSE]), dag_cols = colnames(validity))
## implicit specification weights in the licensed mixture: sum_g w_g / n_g over the worlds licensing each spec (equal world weights, equal within-world weights)
Wn <- colSums(validity); wg <- ifelse(Wn > 0, 1 / sum(Wn > 0), 0)
impw <- sapply(seq_along(subs), function(k) sum(ifelse(validity[k, ], wg / pmax(Wn, 1), 0)))
impw_tab <- data.frame(ctrl = lab, licensed_by = fits$licensed_by, implicit_weight = impw)[impw > 0, ]
capture.output({ print(dec)
  cat("\nWorlds with no admissible set (reported, excluded from rho; remaining world weights renormalised):",
      if (any(Wn == 0)) paste(names(Wn)[Wn == 0], collapse = "; ") else "none", "\n")
  cat("\nImplicit weights of the unique licensed specifications in the equal-weight mixture (sum_g w_g / n_g):\n"); print(impw_tab, row.names = FALSE)
  cat("\nNote: 'within' is dispersion across specifications on the fixed sample (no sampling variance); sampling uncertainty is in j1_bootstrap.csv.\n") },
  file = file.path(outdir, "j1_decomp.txt")); print(dec); print(impw_tab, row.names = FALSE)
fwrite(impw_tab, file.path(outdir, "j1_implicit_weights.csv"))
lic <- fits$licensed_by != "none"
unl <- data.frame(n_specs = nrow(fits), n_licensed = sum(lic), naive_mean = mean(fits$estimate), naive_sd = sd(fits$estimate),
                  naive_min = min(fits$estimate), naive_max = max(fits$estimate), naive_sig_rate = mean(fits$p < .05),
                  licensed_mean = mean(fits$estimate[lic]), licensed_sd = sd(fits$estimate[lic]),
                  licensed_min = min(fits$estimate[lic]), licensed_max = max(fits$estimate[lic]),
                  unlicensed_mean = mean(fits$estimate[!lic]), unlicensed_sd = sd(fits$estimate[!lic]),
                  share_between = dec$share_between)
fwrite(unl, file.path(outdir, "j1_unlicensed.csv")); print(t(unl))

## ---- replication by cohort (first waves 2007 / 2011 / 2019): per-world means ----
byc <- list()
for (co in levels(d$cohort)) { dc <- d[cohort == co]; if (nrow(dc) < 200) next
  rc <- t(sapply(subs, function(s) fit_spec(s, dc)))
  fc <- data.frame(ctrl = lab, estimate = rc[, 1], se = rc[, 2])
  for (w in colnames(validity)) { v <- validity[, w]; byc[[length(byc) + 1]] <- data.frame(cohort = co, n = nrow(dc), dag = w, n_specs = sum(v),
      mean = if (sum(v)) mean(fc$estimate[v]) else NA, sd_model = if (sum(v) > 1) sd(fc$estimate[v]) else if (sum(v)) 0 else NA, mean_se = if (sum(v)) mean(fc$se[v]) else NA) }
  byc[[length(byc) + 1]] <- data.frame(cohort = co, n = nrow(dc), dag = "naive (all 32)", n_specs = 32, mean = mean(fc$estimate), sd_model = sd(fc$estimate), mean_se = mean(fc$se))
}
if (length(byc)) fwrite(rbindlist(byc), file.path(outdir, "j1_by_cohort.csv"))

## ---- (d) common age support by cohort (25-32 = intersection of the three cohorts' analysis ages; 25-31 kept for continuity with v0.6), and maximal sample ----
lic_specs <- list(character(0), "married", "grades", c("married", "grades")); lic_lab <- c("(none)", "married", "grades", "married;grades")
sup <- list()
for (amax in c(32, 31)) {
  for (co in levels(d$cohort)) { dc <- d[cohort == co & age >= 25 & age <= amax]; if (nrow(dc) < 100) next
    r <- t(sapply(lic_specs, fit_spec, data = dc))
    sup[[length(sup) + 1]] <- data.frame(analysis = paste0("common_support_25_", amax), cohort = co, n = nrow(dc), univ_share = round(mean(dc$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2]) }
  dcs <- d[age >= 25 & age <= amax]
  r <- t(sapply(lic_specs, fit_spec, data = dcs))
  sup[[length(sup) + 1]] <- data.frame(analysis = paste0("common_support_25_", amax), cohort = "all", n = nrow(dcs), univ_share = round(mean(dcs$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
}
dmax <- copy(st4b); dmax[, `:=`(peduc_f = factor(peduc), age2 = age^2)]           # 企業規模・職業・雇用形態の欠測を要求しない最大標本
r <- t(sapply(lic_specs, fit_spec, data = dmax))
sup[[length(sup) + 1]] <- data.frame(analysis = "max_sample_licensed_vars_complete", cohort = "all", n = nrow(dmax), univ_share = round(mean(dmax$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
r <- t(sapply(lic_specs, fit_spec, data = d))
sup[[length(sup) + 1]] <- data.frame(analysis = "main_sample", cohort = "all", n = nrow(d), univ_share = round(mean(d$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
## students working in non-regular jobs (wrktype 12) excluded: the education item does not separate current enrolment from completion
dns <- d[wrktype != 12]
r <- t(sapply(lic_specs, fit_spec, data = dns))
sup[[length(sup) + 1]] <- data.frame(analysis = "main_sample_excl_working_students", cohort = "all", n = nrow(dns), univ_share = round(mean(dns$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
## income coded by interval midpoints instead of the option-label representative values
dmp <- copy(d)[!is.na(linc_midpt)]; dmp[, linc := linc_midpt]
r <- t(sapply(lic_specs, fit_spec, data = dmp))
sup[[length(sup) + 1]] <- data.frame(analysis = "main_sample_income_midpoints", cohort = "all", n = nrow(dmp), univ_share = round(mean(dmp$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
## grades as a 4-df categorical variable (R3-O1): licensed specifications only, same sample and other covariates
fit_spec_cat <- function(s, data = d) {
  bl <- if (length(unique(data$cohort)) > 1) baselines else setdiff(baselines, "cohort")
  rhs <- c("univ", sapply(c(bl, s), function(v) if (v == "grades") "factor(grades)" else term(v)))
  m <- lm(as.formula(paste("linc ~", paste(rhs, collapse = "+"))), data)
  cs <- hc1(m, "univ"); c(cs[1], cs[2], 2 * pnorm(-abs(cs[1] / cs[2])))
}
r <- t(sapply(lic_specs, fit_spec_cat, data = d))
sup[[length(sup) + 1]] <- data.frame(analysis = "main_sample_grades_categorical", cohort = "all", n = nrow(d), univ_share = round(mean(d$univ), 3), ctrl = lic_lab, estimate = r[, 1], se = r[, 2])
## 2019 cohort: analysis ages are 25-32 (survey year minus birth year); 25-31 is the common-support subset above
sup[[length(sup) + 1]] <- data.frame(analysis = "age_range_by_cohort", cohort = levels(d$cohort), n = as.integer(table(d$cohort)), univ_share = NA,
                                     ctrl = paste0("ages ", d[, min(age), by = cohort][order(cohort)]$V1, "-", d[, max(age), by = cohort][order(cohort)]$V1), estimate = NA, se = NA)
sup <- rbindlist(sup); sup[n < MIN_CELL, c("univ_share", "estimate", "se") := NA]; sup[, n := supp(n)]
fwrite(sup, file.path(outdir, "j1_support.csv")); cat("\ncommon support / maximal sample:\n"); print(sup)

## ---- (e) top income band sensitivity (band 13 = open top band; baseline midpoint TOP_MID) ----
n_top <- sum(d$inc_band == 13)
tops <- c(baseline = TOP_MID, memo_2250 = 2250, x0.75_below_band_lower_bound = TOP_MID * 0.75, x1.5 = TOP_MID * 1.5)   # 1,875 is below the band's lower bound 2,250: an out-of-band stress value, not an admissible assignment
isens <- rbindlist(lapply(names(tops), function(nm) { d2 <- copy(d); d2[inc_band == 13, linc := log(tops[[nm]])]
  r <- t(sapply(lic_specs, fit_spec, data = d2))
  data.table(variant = nm, top_value_man = tops[[nm]], n_top_band = supp(n_top), ctrl = lic_lab, estimate = r[, 1], se = r[, 2]) }))
isens[, gap_none_minus_grades := estimate[ctrl == "(none)"] - estimate[ctrl == "grades"], by = variant]
fwrite(isens, file.path(outdir, "j1_income_sens.csv")); cat("\ntop-band sensitivity (n in top band:", if (is.na(supp(n_top))) "<10" else n_top, "):\n"); print(isens)

## ---- (b) person-level bootstrap, stratified by cohort, B = B_BOOT, all 32 specifications refitted on each resample ----
## fast path: one model matrix, lm.fit per (resample, spec). Point estimates are checked against fit_spec() (HC1 fits) above.
set.seed(SEED)
fml_all <- ~ univ + peduc_f + age + age2 + female + cohort + occ_f + firm_f + regular + married + grades
MM <- model.matrix(fml_all, d); yv <- d$linc
tl <- attr(terms(fml_all), "term.labels"); colgroup <- c("(Intercept)", tl)[attr(MM, "assign") + 1]
grp_of <- function(v) switch(v, occ = "occ_f", firm = "firm_f", regular = "regular", married = "married", grades = "grades", peduc = "peduc_f", age = c("age", "age2"), female = "female", cohort = "cohort")
cols_for <- function(s, bl) which(colgroup %in% c("(Intercept)", "univ", unlist(lapply(c(bl, s), grp_of))))
est_specs <- function(rows, cols_list) { X <- MM[rows, , drop = FALSE]; y <- yv[rows]
  vapply(cols_list, function(cc) lm.fit(X[, cc, drop = FALSE], y)$coefficients[["univ"]], 0) }
spec_cols <- lapply(subs, cols_for, bl = baselines)
chk <- est_specs(seq_len(nrow(d)), spec_cols); cat(sprintf("\nbootstrap engine check: max |lm.fit - fit_spec| = %.2e\n", max(abs(chk - fits$estimate))))
Wcols <- colnames(validity)[colSums(validity) > 0]                                # worlds that enter rho (W1-W4)
world_stats <- function(est) { mu <- sapply(Wcols, function(w) mean(est[validity[, w]])); vw <- sapply(Wcols, function(w) { e <- est[validity[, w]]; if (length(e) > 1) var(e) * (length(e) - 1) / length(e) else 0 })
  between <- mean((mu - mean(mu))^2); within <- mean(vw); c(mu, rho = if (between + within > 0) between / (between + within) else NA) }
idx_by <- split(seq_len(nrow(d)), d$cohort)
bs <- matrix(NA_real_, B_BOOT, length(subs), dimnames = list(NULL, lab))
t0 <- Sys.time()
for (b in seq_len(B_BOOT)) { ib <- unlist(lapply(idx_by, function(ix) sample(ix, length(ix), replace = TRUE)), use.names = FALSE); bs[b, ] <- est_specs(ib, spec_cols) }
cat(sprintf("bootstrap (pooled, B=%d) done in %.0f s\n", B_BOOT, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
n_boot_ok <- sum(apply(is.finite(bs), 1, all)); cat(sprintf("bootstrap replicates with all 32 estimates finite: %d of %d\n", n_boot_ok, B_BOOT))
ws <- t(apply(bs, 1, world_stats)); ws0 <- world_stats(fits$estimate)
m12 <- rowMeans(ws[, grep("^W1|^W2", Wcols), drop = FALSE]); m34 <- rowMeans(ws[, grep("^W3|^W4", Wcols), drop = FALSE])
m12_0 <- mean(ws0[grep("^W1|^W2", Wcols)]); m34_0 <- mean(ws0[grep("^W3|^W4", Wcols)])
summ <- function(x, point) data.table(point = point, boot_mean = mean(x, na.rm = TRUE), se = sd(x, na.rm = TRUE), q025 = unname(quantile(x, .025, na.rm = TRUE)), q975 = unname(quantile(x, .975, na.rm = TRUE)), p_le0 = mean(x <= 0, na.rm = TRUE),
                                       n_success = sum(is.finite(x)))   # v4: finite replicates for THIS sample and statistic
e0 <- fits$estimate; names(e0) <- lab
rows <- list(
  delta_W34_minus_W12      = summ(m34 - m12, m34_0 - m12_0),
  delta_none_minus_grades  = summ(bs[, "(none)"] - bs[, "grades"], e0[["(none)"]] - e0[["grades"]]),
  delta_married_noGrades   = summ(bs[, "married"] - bs[, "(none)"], e0[["married"]] - e0[["(none)"]]),
  delta_married_grades     = summ(bs[, "married;grades"] - bs[, "grades"], e0[["married;grades"]] - e0[["grades"]]),
  mu_W12                   = summ(m12, m12_0), mu_W34 = summ(m34, m34_0),
  naive_mean               = summ(rowMeans(bs), mean(e0)), licensed_mean = summ((m12 + m34) / 2, (m12_0 + m34_0) / 2),
  unlicensed_mean          = summ(rowMeans(bs[, !lic, drop = FALSE]), mean(e0[!lic])),
  rho_between_share        = summ(ws[, "rho"], ws0[["rho"]]))
for (w in Wcols) rows[[paste0("mu_", substr(w, 1, 2))]] <- summ(ws[, w], ws0[[w]])
boot <- rbindlist(lapply(names(rows), function(q) cbind(sample = "pooled_25_45", quantity = q, rows[[q]])))
## by cohort (full age range) and common support 25-31, licensed specs only: contrast (none) - grades and the two married toggles
lic_cols <- lapply(lic_specs, cols_for, bl = setdiff(baselines, "cohort"))
boot_sub <- function(rows_in, label) { if (length(rows_in) < 100) return(NULL)
  bsub <- matrix(NA_real_, B_BOOT, 4, dimnames = list(NULL, lic_lab)); p0 <- est_specs(rows_in, lic_cols)
  for (b in seq_len(B_BOOT)) bsub[b, ] <- est_specs(sample(rows_in, length(rows_in), replace = TRUE), lic_cols)
  rbindlist(list(cbind(sample = label, quantity = "delta_none_minus_grades", summ(bsub[, "(none)"] - bsub[, "grades"], p0[1] - p0[3])),
                 cbind(sample = label, quantity = "delta_married_noGrades", summ(bsub[, "married"] - bsub[, "(none)"], p0[2] - p0[1])),
                 cbind(sample = label, quantity = "delta_married_grades", summ(bsub[, "married;grades"] - bsub[, "grades"], p0[4] - p0[3])),
                 cbind(sample = label, quantity = "mu_none", summ(bsub[, "(none)"], p0[1])), cbind(sample = label, quantity = "mu_grades", summ(bsub[, "grades"], p0[3])))) }
for (co in levels(d$cohort)) { boot <- rbind(boot, boot_sub(which(d$cohort == co), paste0("cohort_", co, "_25_45")))
  for (amax in c(32, 31)) boot <- rbind(boot, boot_sub(which(d$cohort == co & d$age <= amax), paste0("cohort_", co, "_25_", amax))) }
## pooled common support (25-32 and 25-31) keeps the cohort dummy
lic_cols_pooled <- lapply(lic_specs, cols_for, bl = baselines)
for (amax in c(32, 31)) { cs_rows <- which(d$age <= amax)
  if (length(cs_rows) >= 100) { bsub <- matrix(NA_real_, B_BOOT, 4, dimnames = list(NULL, lic_lab)); p0 <- est_specs(cs_rows, lic_cols_pooled)
    idx_cs <- split(cs_rows, d$cohort[cs_rows])
    for (b in seq_len(B_BOOT)) bsub[b, ] <- est_specs(unlist(lapply(idx_cs, function(ix) sample(ix, length(ix), replace = TRUE)), use.names = FALSE), lic_cols_pooled)
    boot <- rbind(boot, cbind(sample = paste0("pooled_25_", amax), quantity = "delta_none_minus_grades", summ(bsub[, "(none)"] - bsub[, "grades"], p0[1] - p0[3]))) } }
## ---- (b') grades as a 4-df categorical variable in the licensed specifications (R3-O1), same resamples as the pooled bootstrap (seed reset) ----
fml_cat <- ~ univ + peduc_f + age + age2 + female + cohort + married + factor(grades)
MMc <- model.matrix(fml_cat, d); tlc <- attr(terms(fml_cat), "term.labels"); colgroup_c <- c("(Intercept)", tlc)[attr(MMc, "assign") + 1]
grp_c <- function(v) switch(v, married = "married", grades = "factor(grades)", peduc = "peduc_f", age = c("age", "age2"), female = "female", cohort = "cohort")
cols_c <- lapply(lic_specs, function(s) which(colgroup_c %in% c("(Intercept)", "univ", unlist(lapply(c(baselines, s), grp_c)))))
est_c <- function(rows) { X <- MMc[rows, , drop = FALSE]; y <- yv[rows]; vapply(cols_c, function(cc) lm.fit(X[, cc, drop = FALSE], y)$coefficients[["univ"]], 0) }
p0c <- est_c(seq_len(nrow(d))); set.seed(SEED); bsc <- matrix(NA_real_, B_BOOT, 4, dimnames = list(NULL, lic_lab))
for (b in seq_len(B_BOOT)) { ib <- unlist(lapply(idx_by, function(ix) sample(ix, length(ix), replace = TRUE)), use.names = FALSE); bsc[b, ] <- est_c(ib) }
boot <- rbind(boot,
  cbind(sample = "pooled_25_45_grades_categorical", quantity = "delta_none_minus_grades", summ(bsc[, "(none)"] - bsc[, "grades"], p0c[1] - p0c[3])),
  cbind(sample = "pooled_25_45_grades_categorical", quantity = "mu_none", summ(bsc[, "(none)"], p0c[1])),
  cbind(sample = "pooled_25_45_grades_categorical", quantity = "mu_grades", summ(bsc[, "grades"], p0c[3])),
  cbind(sample = "pooled_25_45_grades_categorical", quantity = "mu_married_grades", summ(bsc[, "married;grades"], p0c[4])),
  cbind(sample = "pooled_25_45", quantity = "delta_contrast_linear_minus_categorical", summ((bs[, "(none)"] - bs[, "grades"]) - (bsc[, "(none)"] - bsc[, "grades"]), (e0[["(none)"]] - e0[["grades"]]) - (p0c[1] - p0c[3]))))
cat(sprintf("grades categorical (4 df): (none) %.4f, grades %.4f, contrast %.4f (linear-score contrast %.4f)\n", p0c[1], p0c[3], p0c[1] - p0c[3], e0[["(none)"]] - e0[["grades"]]))
boot[, B := B_BOOT]; boot[, seed := SEED]; boot[, n_all32_finite_pooled := n_boot_ok]; boot[, ci_method := "percentile (q025, q975); se = bootstrap SD; resampling of persons within cohort strata"]
fwrite(boot, file.path(outdir, "j1_bootstrap.csv")); cat("\nbootstrap summary:\n"); print(boot[, .(sample, quantity, point = round(point, 4), se = round(se, 4), q025 = round(q025, 4), q975 = round(q975, 4), p_le0)])

## ---- figure-2 interval statements checked from the output values (not from pixels) ----
lo <- fits$estimate - 1.96 * fits$se; hi <- fits$estimate + 1.96 * fits$se; unl_i <- fits$licensed_by == "none"
fc <- c(sprintf("unlicensed specifications: %d", sum(unl_i)),
        sprintf("  95%% CI (est +/- 1.96 HC1 SE) excludes the W1/W2 value %.3f: %d", fits$estimate[fits$ctrl == "grades"], sum(unl_i & (lo > fits$estimate[fits$ctrl == "grades"] | hi < fits$estimate[fits$ctrl == "grades"]))),
        sprintf("  95%% CI excludes the W3/W4 value %.3f: %d", fits$estimate[fits$ctrl == "(none)"], sum(unl_i & (lo > fits$estimate[fits$ctrl == "(none)"] | hi < fits$estimate[fits$ctrl == "(none)"]))),
        sprintf("  95%% CI excludes the naive mean %.3f: %d", mean(fits$estimate), sum(unl_i & (lo > mean(fits$estimate) | hi < mean(fits$estimate)))),
        sprintf("share of the 2007 cohort in the analysis sample: %.3f", mean(d$cohort == "2007")))
writeLines(fc, file.path(outdir, "j1_fig_checks.txt")); cat(fc, sep = "\n")

## ---- measurement-sensitivity calibration (DC2): E and R residualized on the uncontested controls ----
## classical residualized model Y = tau E + beta G* + eps, R = G* + nu: b_R - tau = (b_0 - tau)(1 - lambda)/(1 - lambda q), q = Corr^2(E, G*),
## and the observed Corr^2(E, R) = lambda * q. Hence tau = b_0 - Delta * (1 - r2) / (lambda - r2) with r2 the observed residualized correlation squared.
rE <- resid(lm(univ ~ peduc_f + age + age2 + female + cohort, d)); rR <- resid(lm(grades ~ peduc_f + age + age2 + female + cohort, d))
r2 <- cor(rE, rR)^2; b0 <- fits$estimate[fits$ctrl == "(none)"]; bR <- fits$estimate[fits$ctrl == "grades"]; Dl <- b0 - bR
cal <- rbindlist(lapply(c(1, .95, .9, .85, .8, .75, .7, .65), function(lam) data.table(lambda = lam, r2_obs = r2, q_implied = r2 / lam,
        tau_two_parameter = if (lam > r2) b0 - Dl * (1 - r2) / (lam - r2) else NA_real_, tau_lambda_only_approx = b0 - Dl / lam)))
fwrite(cal, file.path(outdir, "j1_measurement_calibration.csv")); cat("\nmeasurement calibration (r2 = residualized Corr^2(E,R)):\n"); print(cal)

## ---- figures: specification curve with inclusion matrix (from aggregates), and the DAG figure (no data) ----
j1_draw_specmap(fits, unl$naive_mean, unl$licensed_mean, file.path(outdir, "j1_fig_specmap.png"), n_label = sprintf("N = %s", format(nrow(d), big.mark = ",")))
j1_draw_dag(file.path(outdir, "j1_fig_dag.png"))
writeLines(c(capture.output(sessionInfo()), "", paste("run:", format(Sys.time(), "%Y-%m-%d %H:%M")), paste("B =", B_BOOT, " seed =", SEED, " MIN_CELL =", MIN_CELL)),
           file.path(outdir, "j1_sessionInfo.txt"))
cat("done ->", outdir, "\n")
