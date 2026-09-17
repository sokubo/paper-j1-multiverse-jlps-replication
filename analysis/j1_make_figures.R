# j1_make_figures.R — results/ の集計値(j1_specs.csv, j1_unlicensed.csv, j1_descriptives.csv)から図 1(DAG)と図 2(仕様曲線)を再描画する。
# 個票不要。ローカル再実行の有無にかかわらず、この環境で figures/ を更新できる。
# Usage: Rscript j1_make_figures.R [results_dir] [figures_dir]
args <- commandArgs(trailingOnly = TRUE)
resdir <- if (length(args) >= 1) args[1] else "../results"
figdir <- if (length(args) >= 2) args[2] else "../figures"
script_dir <- { f <- grep("^--file=", commandArgs(), value = TRUE); if (length(f)) dirname(sub("^--file=", "", f[1])) else "." }
source(file.path(script_dir, "j1_fig_helpers.R"))
dir.create(figdir, showWarnings = FALSE, recursive = TRUE)
fits <- read.csv(file.path(resdir, "j1_specs.csv"), stringsAsFactors = FALSE)
unl <- read.csv(file.path(resdir, "j1_unlicensed.csv"))
desc <- read.csv(file.path(resdir, "j1_descriptives.csv"))
N <- desc$n[desc$cohort == "all"]
j1_draw_specmap(fits, unl$naive_mean, unl$licensed_mean, file.path(figdir, "j1_fig_specmap.png"), n_label = if (length(N)) sprintf("N = %s", format(N, big.mark = ",")) else NULL)
j1_draw_dag(file.path(figdir, "j1_fig_dag.png"))
cat("figures written to", figdir, "\n")
