# j1_fig_helpers.R (v1.0, 2026-09-20: 凡例の用語を「許容」・「回顧報告=到達地位の子孫」に統一; v1.1, 2026-09-23: 図の来歴の記録を追加、描画は不変) — 図の描画関数(個票不要: 集計値 j1_specs.csv / j1_unlicensed.csv だけで描ける)。
# j1_jlps_application.R(ローカル実行)と j1_make_figures.R(results/ の集計値から再描画)の双方から source される。
j1_dev <- function(f, w, h) {
  if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png(f, width = w, height = h, units = "in", res = 300)
  else png(f, width = w, height = h, units = "in", res = 300)
}
j1_font <- function() if (Sys.info()[["sysname"]] == "Darwin") "Hiragino Sans" else "Noto Sans CJK JP"

## 図 2: 仕様曲線(上段: 推定値と 95% 区間、下段: 統制変数の投入マトリクス)。形状で世界を区別し、モノクロ印刷でも読める。
j1_draw_specmap <- function(fits, naive_mean, licensed_mean, file, n_label = NULL) {
  o <- order(fits$estimate); f2 <- fits[o, ]; K <- nrow(f2)
  lic <- f2$licensed_by; is12 <- grepl("W1|W2", lic); is34 <- grepl("W3|W4", lic)
  cols <- ifelse(lic == "none", "grey55", ifelse(is12, "#2166ac", "#b2182b"))
  pchs <- ifelse(lic == "none", 1, ifelse(is12, 15, 17))
  vars <- c(occ = "職業", firm = "企業規模", regular = "雇用形態", married = "婚姻", grades = "中学成績")
  inc <- sapply(names(vars), function(v) vapply(strsplit(f2$ctrl, ";"), function(s) v %in% s, TRUE))
  j1_dev(file, 7.5, 5.6); on.exit(dev.off())
  layout(matrix(1:2), heights = c(3, 1.35)); fam <- j1_font()
  par(family = fam, mar = c(0.6, 4.2, 1.2, 1))
  plot(seq_len(K), f2$estimate, pch = pchs, col = cols, cex = ifelse(pchs == 1, 1, 1.25), lwd = 1.5,
       ylim = range(c(f2$estimate - 1.96 * f2$se, f2$estimate + 1.96 * f2$se)), xlim = c(0.5, K + 0.5),
       xlab = "", ylab = "大学在籍の係数(対数所得)", xaxt = "n")
  arrows(seq_len(K), f2$estimate - 1.96 * f2$se, seq_len(K), f2$estimate + 1.96 * f2$se, angle = 90, code = 3, length = 0.02, col = cols)
  abline(h = naive_mean, lty = 2); abline(h = licensed_mean, lty = 1, col = "grey30")
  legend("bottomright", bty = "n", cex = .78, pch = c(15, 17, 1, NA, NA), lty = c(NA, NA, NA, 2, 1), col = c("#2166ac", "#b2182b", "grey55", "black", "grey30"),
         legend = c("W1・W2 が許容(成績=交絡, R=G*)", "W3・W4 が許容(回顧報告=到達地位の子孫)", "どの世界も許容しない(媒介変数を統制)", "素朴な多元宇宙の平均", "許容された仕様の平均"))
  if (!is.null(n_label)) mtext(n_label, side = 3, adj = 1, cex = .7, line = 0.1)
  par(mar = c(2.6, 4.2, 0.2, 1))
  plot(NA, xlim = c(0.5, K + 0.5), ylim = c(0.5, length(vars) + 0.5), xlab = "", ylab = "", xaxt = "n", yaxt = "n", bty = "n")
  axis(2, at = rev(seq_along(vars)), labels = vars, las = 1, cex.axis = .72, tick = FALSE, line = -0.5)
  for (j in seq_along(vars)) { y <- length(vars) + 1 - j
    points(seq_len(K), rep(y, K), pch = ifelse(inc[, j], 16, 1), cex = ifelse(inc[, j], 0.9, 0.35), col = ifelse(inc[, j], "black", "grey70")) }
  axis(1, at = c(1, seq(5, K, 5)), cex.axis = .7, mgp = c(2, 0.4, 0)); mtext("仕様(推定値の昇順; ●=統制変数を投入)", side = 1, line = 1.6, cex = .75)
  invisible(file)
}

## 図 1: 雛形 1 の三つの候補世界(成績=交絡 R=G* / 回顧報告=到達地位の子孫 / 混合)。G* は点線の円(潜在)。婚姻は省略。
j1_draw_dag <- function(file) {
  j1_dev(file, 7.5, 2.6); on.exit(dev.off())
  par(mfrow = c(1, 3), family = j1_font(), mar = c(0.3, 0.3, 1.6, 0.3), xpd = NA)
  node <- function(x, y, lab, lty = 1, r = 0.11, cex = 0.95) { symbols(x, y, circles = r, inches = FALSE, add = TRUE, lty = lty, lwd = 1.2, fg = "black", bg = "white"); text(x, y, lab, cex = cex) }
  edge <- function(p, q, r = 0.11, lty = 1, curve = 0) {
    d <- q - p; L <- sqrt(sum(d^2)); u <- d / L; a <- p + u * r; b <- q - u * r
    if (curve == 0) arrows(a[1], a[2], b[1], b[2], length = 0.08, lwd = 1.2, lty = lty)
    else { m <- (a + b) / 2 + c(-u[2], u[1]) * curve; t <- seq(0, 1, length.out = 40)
      xs <- (1 - t)^2 * a[1] + 2 * (1 - t) * t * m[1] + t^2 * b[1]; ys <- (1 - t)^2 * a[2] + 2 * (1 - t) * t * m[2] + t^2 * b[2]
      lines(xs, ys, lwd = 1.2, lty = lty); arrows(xs[38], ys[38], xs[40], ys[40], length = 0.08, lwd = 1.2, lty = lty) }
  }
  P <- list(C = c(0.5, 0.9), G = c(0.14, 0.58), R = c(0.34, 0.1), E = c(0.55, 0.42), Y = c(0.9, 0.42))
  panel <- function(title, gstar_lab, gstar_lty, g_to_y, show_R, r_from_EY) {
    plot(NA, xlim = c(0, 1.02), ylim = c(0, 1), asp = 1, axes = FALSE, xlab = "", ylab = "")
    mtext(title, side = 3, line = 0.2, cex = 0.72, font = 2)
    edge(P$C, P$E); edge(P$C, P$Y); edge(P$C, P$G)
    edge(P$G, P$E); if (g_to_y) edge(P$G, P$Y, curve = 0.3)
    edge(P$E, P$Y)
    if (show_R) { edge(P$G, P$R); if (r_from_EY) { edge(P$E, P$R); edge(P$Y, P$R) } }
    node(P$C[1], P$C[2], "C", cex = 0.85); node(P$E[1], P$E[2], "E"); node(P$Y[1], P$Y[2], "Y")
    node(P$G[1], P$G[2], gstar_lab, lty = gstar_lty, cex = if (nchar(gstar_lab) > 2) 0.72 else 0.95)
    if (show_R) node(P$R[1], P$R[2], "R")
  }
  panel("(a) 成績=交絡(W1・W2): R = G*", "G*=R", 1, TRUE, FALSE, FALSE)
  panel("(b) 回顧報告=到達地位の子孫(W3・W4)", "G*", 3, FALSE, TRUE, TRUE)
  panel("(c) 混合(W5): 調整では識別不能", "G*", 3, TRUE, TRUE, TRUE)
  invisible(file)
}

## v1.1(2026-09-23, 知人査読第 5 回 R5-m2): 図の来歴。PNG のバイトは描画環境(R・グラフィック装置・フォント)で変わるので、
## 図の対応を (1) 数値の入力(集計 CSV の SHA-256)、(2) ラベルの内容(描画コード j1_fig_helpers.R の SHA-256)、(3) 描画環境
## に分けて記録する。j1_make_figures.R が図と同じフォルダに j1_fig_provenance.txt を書く(日時は含めない)。
j1_sha256 <- function(f) {
  if (!file.exists(f)) return(NA_character_)
  if (exists("sha256sum", asNamespace("tools"))) return(unname(as.character(get("sha256sum", asNamespace("tools"))(f))))
  if (requireNamespace("openssl", quietly = TRUE)) return(paste(as.character(unclass(openssl::sha256(file(f)))), collapse = ""))
  r <- tryCatch(suppressWarnings(system2("shasum", c("-a", "256", shQuote(f)), stdout = TRUE, stderr = FALSE)), error = function(e) character(0))
  if (!length(r)) r <- tryCatch(suppressWarnings(system2("sha256sum", shQuote(f), stdout = TRUE, stderr = FALSE)), error = function(e) character(0))
  if (length(r)) sub(" .*", "", r[1]) else NA_character_
}
j1_fig_inputs <- c("j1_specs.csv", "j1_unlicensed.csv", "j1_descriptives.csv")
j1_fig_files <- c("j1_fig_dag.png", "j1_fig_specmap.png")
j1_write_fig_provenance <- function(figdir, resdir, helper_file) {
  dev <- if (requireNamespace("ragg", quietly = TRUE)) paste0("ragg ", as.character(utils::packageVersion("ragg"))) else "grDevices::png"
  lines <- c("# j1 figure provenance (written by j1_make_figures.R): data inputs, drawing code and drawing environment of the PNGs in this folder",
             sprintf("input  %-20s %s", j1_fig_inputs, vapply(file.path(resdir, j1_fig_inputs), j1_sha256, "")),
             sprintf("code   %-20s %s", basename(helper_file), j1_sha256(helper_file)),
             sprintf("env    R_%s.%s %s %s font=%s", R.version$major, R.version$minor, R.version$platform, gsub(" ", "_", dev), gsub(" ", "_", j1_font())),
             sprintf("output %-20s %s", j1_fig_files, vapply(file.path(figdir, j1_fig_files), j1_sha256, "")))
  writeLines(lines, file.path(figdir, "j1_fig_provenance.txt"))
  invisible(lines)
}
