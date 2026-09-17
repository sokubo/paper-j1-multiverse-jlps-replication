## j1_worked_example.R -- 『理論と方法』解説論文 §5 の実行例(設計されたシミュレーション。実データではない)
## 使い方: Rscript j1_worked_example.R   -> output/j1_example_output.txt, output/j1_example_plot.png
suppressPackageStartupMessages(library(dagmv))
set.seed(2026)
dir.create("output", showWarnings = FALSE)

## 1. データ生成: 真の構造は「職業は媒介、婚姻はコライダー」
n <- 5000
pses    <- rnorm(n)                                  # 親の社会経済的地位(交絡, 争いなし)
female  <- rbinom(n, 1, 0.5)                          # 性別(交絡, 争いなし)
univ    <- rbinom(n, 1, plogis(-0.3 + 0.8 * pses - 0.4 * female))   # 処置: 大学在籍
occ     <- 0.6 * univ + 0.2 * pses + rnorm(n)         # 職業威信(媒介: 大学在籍 -> 職業 -> 賃金)
lwage   <- 0.20 * univ + 0.25 * occ + 0.30 * pses - 0.25 * female + rnorm(n, sd = 0.6)  # 総効果 = 0.20 + 0.6*0.25 = 0.35
married <- rbinom(n, 1, plogis(-0.5 + 0.8 * univ + 0.8 * lwage))    # コライダー: 大学在籍と賃金の共通の結果
d <- data.frame(pses, female, univ, occ, lwage, married)
true_total <- 0.20 + 0.6 * 0.25

## 2. 候補DAG: 争点A(職業: 媒介 vs 交絡) x 争点B(婚姻: 精度変数 vs コライダー)
base <- "pses -> univ ; pses -> lwage ; female -> univ ; female -> lwage ; univ -> lwage ; pses -> occ ;"
dags <- list(
  A_med_B_prec = dag_parse(paste("dag {", base, "univ -> occ ; occ -> lwage ; married -> lwage }")),
  A_med_B_coll = dag_parse(paste("dag {", base, "univ -> occ ; occ -> lwage ; univ -> married ; lwage -> married }")),
  A_conf_B_prec = dag_parse(paste("dag {", base, "occ -> univ ; occ -> lwage ; married -> lwage }")),
  A_conf_B_coll = dag_parse(paste("dag {", base, "occ -> univ ; occ -> lwage ; univ -> married ; lwage -> married }"))
)
ctrl <- c("pses", "female", "occ", "married")

sink("output/j1_example_output.txt")
cat("真の総効果 =", true_total, "\n\n## 役割分類表(世界ごと)\n")
for (nm in names(dags)) { cat("\n[", nm, "]\n"); print(mv_classify(dags[[nm]], ctrl, exposure = "univ", outcome = "lwage")) }

## 3. 多元宇宙を一度走らせ、世界ごとの妥当性を対応づける
fits <- mv_run(d, outcome = "lwage", exposure = "univ", controls = ctrl, dags = dags)
cat("\n## 仕様一覧(先頭)\n"); print(head(fits$fits, 8))
cat("\n## 素朴な多元宇宙(全", nrow(fits$fits), "仕様)\n")
est <- fits$fits$estimate; se <- fits$fits$se
cat(sprintf("平均 %.3f  モデリングSD %.3f  符号安定性 %.1f%%  有意率 %.1f%%\n",
            mean(est), sd(est), 100 * mean(sign(est) == sign(median(est))), 100 * mean(abs(est / se) > 1.96)))
cat("\n## 分解\n"); dec <- mv_decompose(fits); print(dec)
sink()
png("output/j1_example_plot.png", width = 1600, height = 900, res = 200)
try(mv_plot(fits), silent = TRUE)
dev.off()
cat("done\n")

## 5. 図1: 仕様マップ(16仕様 × 4世界。認可される仕様を色付き、真値と素朴平均を縦線で)
suppressPackageStartupMessages(library(ggplot2))
## 日本語フォント: 環境にあるものを使う(macOS: Hiragino Sans, Linux: Noto Sans CJK JP)
jp_font <- { f <- c("Hiragino Sans", "Noto Sans CJK JP", "IPAexGothic", "sans"); f[which(f %in% c(systemfonts::system_fonts()$family, "sans"))[1]] }
if (is.na(jp_font)) jp_font <- "sans"
sp <- fits$fits; V <- fits$validity
lab <- c(A_med_B_prec = "職業=媒介 / 婚姻=精度", A_med_B_coll = "職業=媒介 / 婚姻=コライダー(真)",
         A_conf_B_prec = "職業=交絡 / 婚姻=精度", A_conf_B_coll = "職業=交絡 / 婚姻=コライダー")
pd <- do.call(rbind, lapply(colnames(V), function(w) data.frame(world = lab[w], spec = ifelse(sp$spec == "", "(統制なし)", sp$spec),
                 estimate = sp$estimate, lo = sp$estimate - 1.96 * sp$se, hi = sp$estimate + 1.96 * sp$se, valid = V[, w])))
pd$world <- factor(pd$world, levels = lab); pd$spec <- factor(pd$spec, levels = ifelse(sp$spec == "", "(統制なし)", sp$spec)[order(sp$estimate)])
p <- ggplot(pd, aes(x = estimate, y = spec, colour = valid)) +
  geom_vline(xintercept = true_total, linetype = 1, colour = "grey30") +
  geom_vline(xintercept = mean(sp$estimate), linetype = 2, colour = "grey50") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.4) + geom_point(size = 1.8) +
  facet_wrap(~ world, ncol = 2) + scale_colour_manual(values = c(`TRUE` = "#1f5fbf", `FALSE` = "grey75"), labels = c("認可されない", "認可される"), name = NULL) +
  labs(x = "推定値(実線: 真の総効果 0.35、破線: 素朴な平均)", y = "統制集合") + theme_minimal(base_size = 9) +
  theme(legend.position = "bottom", text = element_text(family = jp_font))
ggsave("output/j1_fig1_specmap.png", p, width = 7.5, height = 6.5, dpi = 200, device = if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else "png")
cat("fig1 written\n")
