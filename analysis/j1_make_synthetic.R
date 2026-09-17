# j1_make_synthetic.R — synthetic wide file with the JLPS first-wave variable names used by j1_jlps_application.R.
# For pipeline debugging ONLY; never report numbers from it.
set.seed(7)
mk <- function(n, year, pre, w1 = FALSE) {
  peduc <- sample(1:6, n, TRUE, prob = c(.1,.4,.1,.15,.2,.05)); grades <- pmin(pmax(round(rnorm(n, 3 - .3*(peduc-3), 1)), 1), 5)  # 1=上
  ability <- rnorm(n) - .3*(grades-3)
  univ <- rbinom(n, 1, plogis(-1 + .4*(peduc-3) + .6*ability)); educ <- ifelse(univ==1, sample(5:6, n, TRUE, prob=c(.85,.15)), sample(1:4, n, TRUE, prob=c(.05,.5,.25,.2)))
  regular <- rbinom(n, 1, plogis(.2 + .8*univ)); occ <- ifelse(runif(n) < .3 + .3*univ, sample(1:3, n, TRUE), sample(4:8, n, TRUE))
  firm <- pmin(pmax(round(rnorm(n, 4.5 + 1.2*univ, 2)), 1), 9)
  sex <- sample(1:2, n, TRUE); ybirth <- year - sample(23:45, n, TRUE)
  linc <- 5.3 + .35*univ + .15*ability + .25*regular + .05*firm - .5*(sex==2) + .02*(year-ybirth-30) + rnorm(n, 0, .5)
  married <- rbinom(n, 1, plogis(-.5 + .3*univ + .4*(linc-5.5)))   # collider
  band <- cut(exp(linc), c(-Inf, 12.5, 37.5, 75, 150, 250, 350, 450, 600, 850, 1250, 1750, 2250, Inf), labels = FALSE)
  d <- data.frame(sex, ybirth, e = educ, g = grades, pa = peduc, ma = pmax(1, peduc - sample(0:1, n, TRUE)),
                  m = if (w1) ifelse(married==1, 2, sample(c(1,1,1,3,4), n, TRUE)) else married*1 + (1-married)*2,
                  i = band, wt = ifelse(regular==1, 2, sample(c(3,3,4,5,12,6,10), n, TRUE)), oc = occ, fi = firm)
  names(d) <- c("sex","ybirth", pre$educ, pre$grade, pre$pa, pre$ma, pre$mar, pre$inc, pre$wt, pre$occ, pre$firm); d
}
a <- mk(4800, 2007, list(educ="ZQ23A", grade="ZQ17", pa="ZQ23C", ma="ZQ23D", mar="ZQ50", inc="ZQ47A", wt="JC_1", occ="JC_2", firm="JC_6"), w1 = TRUE); a$ZQ03 <- 1
b <- mk(963, 2011, list(educ="DQ69A", grade="DQ61", pa="DQ69C", ma="DQ69D", mar="DQ43", inc="DQ35A", wt="DQ03_1", occ="DQ03_2", firm="DQ03_7")); b$DQ02 <- 1
c <- mk(2383, 2019, list(educ="LQ72A", grade="LQ65", pa="LQ72B", ma="LQ72C", mar="LQ44RE_2", inc="LQ37A", wt="LQ03_1", occ="LQ03_2", firm="LQ03_7")); c$LQ02 <- 1
all <- data.table::rbindlist(list(a, b, c), fill = TRUE); all[, panelid := .I]
out <- { a <- commandArgs(trailingOnly = TRUE); if (length(a) >= 1) a[1] else "synthetic/j1_synth_wide.rds" }   # v2: optional output path (release check writes elsewhere and compares)
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE); saveRDS(as.data.frame(all), out); cat("synthetic written:", nrow(all), "x", ncol(all), "->", out, "\n")
