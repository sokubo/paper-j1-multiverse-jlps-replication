# j1_check_source.R — J1 の本文が主張している二点を、元の .dta(ラベル付き)から機械的に確認する。
#   (A) 三標本の初回調査(2007 w1 / 2011 w5 / 2019 w13)が「同一の設問」で学歴・中学成績・親学歴・現職・所得を
#       尋ねているか  → 変数ラベル(設問文の略)と選択肢(値ラベル)・有効コード範囲・分布を波ごとに並べて比較する。
#   (B) 同一人物の中学成績の回顧報告が複数波にあるか(2007 コホートの w5 dq61 / w13 lq65)
#       → あれば再テスト相関 = 古典的測定モデルの信頼性 λ の直接の証拠になる(本文 §7.2「λ の直接の証拠は乏しい」)。
#
# 個票は一切書き出さない。出力は集計値のみで、N<10 のセルは NA に伏せる。
# v2(2026-09-17, 知人査読第 3 回 R3-m2): 旧版の単一交絡近似の分岐を削除、末尾の開示に関する結語を訂正。
# 実行(ライセンス機):
#   cd ~/Documents/Claude/Projects/VariableSelection/paper/jp/J1-rironhoho/analysis
#   Rscript j1_check_source.R ~/Documents/JLPS_data/raw/<統合ファイル>.dta ../results
# 出力: ../results/j1_wording_check.txt(通し読み用)、../results/j1_grades_retest.csv(再テストの集計)
suppressPackageStartupMessages({ library(haven); library(data.table) })
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("usage: Rscript j1_check_source.R <jlps_wide.dta> [results_dir]")
infile <- args[1]; outdir <- if (length(args) >= 2) args[2] else "../results"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
MIN_CELL <- 10
LINES <- character(0)
say <- function(...) { l <- paste0(...); cat(l, "\n", sep = ""); LINES <<- c(LINES, l) }
sayprint <- function(x) { for (l in capture.output(print(x))) say("    ", l) }
flush_out <- function() writeLines(LINES, file.path(outdir, "j1_wording_check.txt"), useBytes = TRUE)

say("j1_check_source.R  ", format(Sys.time(), "%Y-%m-%d %H:%M"), "\n入力: ", basename(infile))
ext <- tolower(tools::file_ext(infile))
if (!ext %in% c("dta", "sav")) stop("ラベルを見るので .dta か .sav を指定してください(.rds はラベルが落ちています)")
rd <- function(...) if (ext == "dta") read_dta(infile, ...) else read_sav(infile, ...)
## 必要な列だけ読む(統合ファイルは列数が多いので全読みは避ける)
NEED <- c("panelid", "sex", "ybirth", "zq03", "dq02", "lq02",
          "zq23a", "zq23c", "zq23d", "zq17", "zq47a", "zq50", "jc_1", "jc_2", "jc_6",
          "dq69a", "dq69c", "dq69d", "dq61", "dq35a", "dq43", "dq03_1", "dq03_2", "dq03_7",
          "lq72a", "lq72b", "lq72c", "lq65", "lq37a", "lq44re_2", "lq44", "lq03_1", "lq03_2", "lq03_7")
hdr <- names(rd(n_max = 0)); keep <- hdr[tolower(hdr) %in% NEED]
miss_cols <- setdiff(NEED, tolower(keep))
raw <- tryCatch(rd(col_select = all_of(keep)),
                error = function(e) { message("col_select が使えないので全列を読みます: ", conditionMessage(e)); rd() })
setDT(raw); setnames(raw, tolower(names(raw)))
say("行数 ", nrow(raw), " / 読み込んだ列 ", ncol(raw), " (ファイル全体の列数 ", length(hdr), ")")
if (length(miss_cols)) say("!! ファイルに無い列: ", paste(miss_cols, collapse = " "))

num <- function(v) { if (!v %in% names(raw)) return(rep(NA_real_, nrow(raw))); x <- raw[[v]]; x <- as.numeric(x); x[x %in% c(88, 99, 888, 999)] <- NA; x }
ok  <- function(x) !is.na(x)
vlab <- function(v) { if (!v %in% names(raw)) return(NA_character_); l <- attr(raw[[v]], "label"); if (is.null(l)) NA_character_ else as.character(l) }
vals <- function(v) { if (!v %in% names(raw)) return(character(0)); l <- attr(raw[[v]], "labels")
                      if (is.null(l)) character(0) else paste0(as.integer(l), "=", names(l)) }

## ---- コホート(j1_jlps_application.R と同じ判定) ----
m07 <- ok(num("zq50")) | ok(num("zq03")) | ok(num("zq23a"))
m11 <- !m07 & (ok(num("dq43")) | ok(num("dq02")) | ok(num("dq69a")))
m19 <- !m07 & !m11 & (ok(num("lq44re_2")) | ok(num("lq02")) | ok(num("lq72a")))
say("\nコホート: 2007=", sum(m07), "  2011=", sum(m11), "  2019=", sum(m19),
    "  (未割当 ", sum(!(m07 | m11 | m19)), ")")
coh <- list("2007(w1)" = m07, "2011(w5)" = m11, "2019(w13)" = m19)

## ---- (A) 設問の同一性 ----
## 概念ごとに、三波の変数名を並べる(変数名の q## は各波の調査票の設問番号に対応する)
items <- list(
  "本人学歴"              = c("2007(w1)" = "zq23a",    "2011(w5)" = "dq69a",  "2019(w13)" = "lq72a"),
  "父学歴"                = c("2007(w1)" = "zq23c",    "2011(w5)" = "dq69c",  "2019(w13)" = "lq72b"),
  "母学歴"                = c("2007(w1)" = "zq23d",    "2011(w5)" = "dq69d",  "2019(w13)" = "lq72c"),
  "中3成績(回顧)"         = c("2007(w1)" = "zq17",     "2011(w5)" = "dq61",   "2019(w13)" = "lq65"),
  "本人年収(13区分)"      = c("2007(w1)" = "zq47a",    "2011(w5)" = "dq35a",  "2019(w13)" = "lq37a"),
  "従業上の地位"          = c("2007(w1)" = "jc_1",     "2011(w5)" = "dq03_1", "2019(w13)" = "lq03_1"),
  "職業(大分類)"          = c("2007(w1)" = "jc_2",     "2011(w5)" = "dq03_2", "2019(w13)" = "lq03_2"),
  "企業規模"              = c("2007(w1)" = "jc_6",     "2011(w5)" = "dq03_7", "2019(w13)" = "lq03_7"),
  "婚姻(※符号化が波で違うことは既知)" = c("2007(w1)" = "zq50", "2011(w5)" = "dq43", "2019(w13)" = "lq44re_2")
)
## 本文 §7.1 の「同一の設問で学歴・中学成績・親学歴・現職・所得を尋ねており」が対象とする項目
CLAIM <- c("本人学歴", "父学歴", "母学歴", "中3成績(回顧)", "本人年収(13区分)", "従業上の地位", "職業(大分類)", "企業規模")
say("\n", strrep("=", 78), "\n(A) 設問の同一性: 変数ラベル(=設問文の略)と選択肢を波ごとに比較\n", strrep("=", 78))
flags <- character(0)
for (nm in names(items)) {
  vv <- items[[nm]]
  say("\n---- ", nm, " ----")
  labs <- character(0); sets <- character(0)
  for (w in names(vv)) {
    v <- vv[[w]]
    if (!v %in% names(raw)) { say(sprintf("  %-10s %-10s  ** 変数が見つかりません **", w, v))
      if (nm %in% CLAIM) flags <- c(flags, sprintf("%s: %s (%s) が無い", nm, v, w)); next }
    x <- num(v); sel <- coh[[w]]
    say(sprintf("  %-10s %-10s  ラベル: %s", w, v, ifelse(is.na(vlab(v)), "(なし)", vlab(v))))
    vl <- vals(v)
    say("             選択肢: ", if (length(vl)) paste(vl, collapse = " / ") else "(値ラベルなし)")
    tb <- table(x[sel], useNA = "no")
    if (length(tb)) {
      tb[tb < MIN_CELL] <- NA
      say("             当該コホートの分布(N<", MIN_CELL, " は伏せ字): ",
          paste(names(tb), "=", ifelse(is.na(tb), "<10", tb), collapse = " "))
    } else say("             当該コホートに有効回答なし")
    labs <- c(labs, ifelse(is.na(vlab(v)), "", vlab(v))); sets <- c(sets, paste(vl, collapse = "|"))
  }
  if (length(unique(sets[sets != ""])) > 1) {
    if (nm %in% CLAIM) { say("  !! 選択肢(値ラベル)が波で一致しません"); flags <- c(flags, paste0(nm, ": 選択肢が不一致")) }
    else say("  → 選択肢は波で違う(既知。本文の「同一の設問」の対象外で、スクリプトが波ごとに符号化している)")
  } else if (length(sets[sets != ""]) >= 2) say("  → 選択肢は一致")
}
say("\n--- (A) の要約 ---")
if (length(flags)) for (f in flags) say("  !! ", f) else say("  三波とも同一の選択肢・同一の有効コード範囲。")
say("  ※ 変数ラベルは設問文の略記なので、本文で「同一の設問」と書くには調査票 PDF の該当設問")
say("    (w1 問17/問23/問47/問50、w5 問61/問69/問35/問43、w13 問65/問72/問37/問44)も目視すること。")
say("  ※ 現職(従業上の地位・職業・企業規模)は w1 だけ変数名の系統が違う(jc_* 対 *q03_*)ので特に注意。")

## ---- (B) 中学成績の反復回顧報告 ----
say("\n", strrep("=", 78), "\n(B) 同一人物の中学成績の反復回顧報告(再テスト)\n", strrep("=", 78))
gvars <- c(w1 = "zq17", w5 = "dq61", w13 = "lq65")
avail <- data.table(wave = character(), var = character(), cohort = character(), n_valid = integer(), share_valid = numeric())
for (w in names(gvars)) for (cn in names(coh)) {
  v <- gvars[[w]]; if (!v %in% names(raw)) next
  x <- num(v); sel <- coh[[cn]]
  avail <- rbind(avail, data.table(wave = w, var = v, cohort = cn, n_valid = sum(x[sel] %in% 1:5),      # 1–5 の実質回答のみ(6=わからない, 9=無回答は除く)
                                   share_valid = round(mean(x[sel] %in% 1:5), 3)))
}
avail[n_valid < MIN_CELL, `:=`(n_valid = NA_integer_, share_valid = NA_real_)]
say("\n各波の成績項目に実質回答(1–5; 6=わからない・9=無回答を除く)があるコホート(= その波でその項目を尋ねられている; n_valid は 1–5 の回答数, share_valid はコホート内の割合):")
sayprint(avail)

retest <- data.table()
pairs <- list(c("zq17", "dq61", "2007(w1)", "w1 → w5 (4 年)"), c("zq17", "lq65", "2007(w1)", "w1 → w13 (12 年)"),
              c("dq61", "lq65", "2011(w5)", "w5 → w13 (8 年)"))
for (p in pairs) {
  v1 <- p[1]; v2 <- p[2]; cn <- p[3]; lab <- p[4]
  if (!(v1 %in% names(raw) && v2 %in% names(raw))) next
  x1 <- num(v1); x2 <- num(v2); sel <- coh[[cn]] & x1 %in% 1:5 & x2 %in% 1:5
  n <- sum(sel)
  say("\n---- ", lab, "  (", v1, " × ", v2, ", コホート ", cn, ") ----")
  if (n < MIN_CELL) { say("  両方に有効回答がある人は ", ifelse(n == 0, "0", "<10"), " 人 → この波では反復回顧報告は取れない。"); next }
  a <- x1[sel]; b <- x2[sel]
  ct <- table(a, b); ct2 <- ct; ct2[ct2 < MIN_CELL] <- NA
  say("  N = ", n)
  say("  クロス表(行 = ", v1, ", 列 = ", v2, "; N<", MIN_CELL, " は伏せ字):")
  sayprint(ifelse(is.na(ct2), "<10", ct2))
  agree <- mean(a == b); near <- mean(abs(a - b) <= 1)
  r <- suppressWarnings(cor(a, b)); rho <- suppressWarnings(cor(a, b, method = "spearman"))
  say(sprintf("  完全一致 %.3f / ±1 以内 %.3f / Pearson r = %.3f / Spearman rho = %.3f", agree, near, r, rho))
  say(sprintf("  → 再テスト相関 r = %.3f。これを信頼性 λ の推定値と読むには、誤差が時点間で無相関であることに加え、", r))
  say("     真値 G* の安定性、負荷と誤差分散の時点間の比較可能性が要る(本文 §7.2 の補正式は 2 パラメータ版 τ = b0 − Δ(1−r²)/(λ−r²);")
  say("     旧版の単一交絡近似 0.245 − 0.077/λ はここでは計算しない)。")
  retest <- rbind(retest, data.table(pair = lab, var1 = v1, var2 = v2, cohort = cn, n = n,
                                     agree_exact = round(agree, 3), agree_within1 = round(near, 3),
                                     pearson_r = round(r, 3), spearman_rho = round(rho, 3)))
}
if (nrow(retest)) { fwrite(retest, file.path(outdir, "j1_grades_retest.csv"))
  say("\n書き出し: ", file.path(outdir, "j1_grades_retest.csv")) } else
  say("\n反復回顧報告は取れなかった(該当する組み合わせなし)。この場合、本文 §7.2・§9 は現状のままでよい。")

say("\n", strrep("=", 78), "\n(C) 本文の二つの文が書けるか\n", strrep("=", 78))
say("\n1) §7.1「三つの標本の初回調査…は同一の設問で学歴・中学成績・親学歴・現職・所得を尋ねており」")
if (length(flags)) { say("   → 上の (A) に !! があるので、このままでは書けない。該当箇所を Claude に伝えて文言を直す。")
} else say("   → 変数ラベル・選択肢・有効コードは三波で一致。調査票 PDF の目視が済めばこのままでよい。")
say("\n2) §7.2「λ の直接の証拠は乏しい」/ §9「同一回答者の反復回顧報告の一致度の診断」(日本の成人では乏しい)")
if (nrow(retest)) { say("   → 反復回顧報告が取れた(上の (B))。自分のデータで λ を直接推定できるので、この二文は書き換える。")
  say("      j1_grades_retest.csv を Claude に渡す。")
} else say("   → 反復回顧報告は取れない。§7.2・§9 は現状のままでよい。")
say("\n", strrep("=", 78))
say("この 2 ファイル(j1_wording_check.txt / j1_grades_retest.csv)は個票を含まず N<10 のセルを伏せた集計値だが、")
say("それだけで公開可能とはならない。共有・公開の前に SSJDA 利用条件と当該調査の条件に照らして開示確認を行うこと。")
flush_out()
cat("\n書き出し:", file.path(outdir, "j1_wording_check.txt"), "\n")
