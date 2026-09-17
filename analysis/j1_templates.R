## j1_templates.R -- §6 日本の調査データにおける候補DAGの雛形(役割分類表を dagmv で計算)
## v2 (2026-09-17): 雛形 1 を本文 v0.8 の W1–W5(G*/R の区別)に更新(知人査読第 3 回 R3-m2)。雛形 2・3 は不変。
suppressPackageStartupMessages(library(dagmv))
dir.create("output", showWarnings = FALSE)
sink("output/j1_templates_output.txt")
show <- function(title, dags, ctrl, x, y) {
  cat("\n####", title, "\n")
  for (nm in names(dags)) { cat("\n[", nm, "]\n")
    r <- tryCatch(mv_classify(dags[[nm]], ctrl, exposure = x, outcome = y), error = function(e) conditionMessage(e))
    print(r) }
}
## 雛形1(v2, 2026-09-17 = 本文 §6 表 1 と §7 の実装に一致): 大学在籍(educ) -> 所得(inc)。
##   争いなし: 親学歴(peduc)・年齢(age)・性別(female)・調査年(cohort)は交絡; 職業(occ)・企業規模(firm)・雇用形態(regular)は媒介。
##   争点A: 中 3 時の実際の成績 G*(gstar, 潜在)と回顧報告 R(grades)を区別する。
##     W1/W2 成績=交絡(R ≡ G*): grades -> educ, grades -> inc。  W3/W4 成績=回顧の子孫: gstar -> educ のみ、grades は educ・inc の子孫。
##     W5 混合: gstar -> educ と gstar -> inc の両方があり、grades は gstar と到達地位の双方の子孫 → 妥当集合なし。
##   争点B: 婚姻(married)はコライダー(W1・W3・W5)か精度変数(W2・W4)か。
##   DAG 文字列は analysis/j1_jlps_application.R と同一(そちらが正本)。旧版の雛形 1(region・firstjob・40 歳時所得の教育用例)は
##   j1_templates_v1_backup.R に残す。
base <- "peduc -> educ ; peduc -> inc ; age -> educ ; age -> inc ; female -> educ ; female -> inc ; cohort -> educ ; cohort -> inc ; educ -> inc ;
         educ -> occ ; occ -> inc ; educ -> firm ; firm -> inc ; educ -> regular ; regular -> inc ; peduc -> occ ; peduc -> firm"
gr_conf <- "grades -> educ ; grades -> inc ; peduc -> grades"
gr_desc <- "gstar [latent] ; gstar -> educ ; gstar -> grades ; peduc -> gstar ; educ -> grades ; inc -> grades"
gr_mix  <- "gstar [latent] ; gstar -> educ ; gstar -> inc ; gstar -> grades ; peduc -> gstar ; educ -> grades ; inc -> grades"
ma_coll <- "educ -> married ; inc -> married"
ma_prec <- "married -> inc"
mk <- function(...) paste("dag {", paste(c(base, ...), collapse = " ; "), "}")
t1 <- list("W1 成績=交絡(R=G*)・婚姻=コライダー" = dag_parse(mk(gr_conf, ma_coll)), "W2 成績=交絡(R=G*)・婚姻=精度変数" = dag_parse(mk(gr_conf, ma_prec)),
           "W3 成績=回顧の子孫・婚姻=コライダー" = dag_parse(mk(gr_desc, ma_coll)), "W4 成績=回顧の子孫・婚姻=精度変数" = dag_parse(mk(gr_desc, ma_prec)),
           "W5 成績=混合(G*潜在)・婚姻=コライダー" = dag_parse(mk(gr_mix, ma_coll)))
show("雛形1 学歴と所得(W1–W5)", t1, c("peduc", "age", "female", "cohort", "grades", "married", "occ", "firm", "regular"), "educ", "inc")
## 雛形2: 女性の結婚(marry) -> 就業継続(work)。争点A: 子ども(child)は媒介(結婚->出産->退職)か交絡(妊娠先行婚)か
##        争点B: 親との同居(cores)は媒介(結婚->別居)か交絡(親同居が結婚を遅らせ就業継続を助ける)か
##        争いなし: 本人学歴(educ)・初職の雇用形態(firstreg)・都市規模(urban)は交絡。
##        付録: 「夫の所得(hinc)は未測定の配偶者選択要因Uの代理」という世界は妥当な調整集合を持たない(識別不能世界)。
b2 <- "educ -> marry ; educ -> work ; firstreg -> marry ; firstreg -> work ; urban -> marry ; urban -> work ; marry -> work ;"
t2 <- list(
  "子=媒介 / 親同居=媒介" = dag_parse(paste("dag {", b2, "marry -> child ; child -> work ; marry -> cores ; cores -> work }")),
  "子=交絡 / 親同居=媒介" = dag_parse(paste("dag {", b2, "child -> marry ; child -> work ; marry -> cores ; cores -> work }")),
  "子=媒介 / 親同居=交絡" = dag_parse(paste("dag {", b2, "marry -> child ; child -> work ; cores -> marry ; cores -> work }")),
  "子=交絡 / 親同居=交絡" = dag_parse(paste("dag {", b2, "child -> marry ; child -> work ; cores -> marry ; cores -> work }"))
)
show("雛形2 婚姻と就業", t2, c("educ", "firstreg", "urban", "child", "cores"), "marry", "work")
t2x <- list("付録: 夫所得=未測定Uの代理" = dag_parse(paste("dag {", b2, "marry -> child ; child -> work ; U -> marry ; U -> hinc ; hinc -> work ; U -> work }")))
show("雛形2 付録(識別不能世界)", t2x, c("educ", "firstreg", "urban", "child", "hinc"), "marry", "work")
## 雛形3: 大都市居住(city) -> 主観的健康(health)。争点A: 所得(inc)は媒介(都市->所得->健康)か交絡(選択的移動: 所得が移住を規定)か
##        争点B: 社会的つながり(ties)は媒介か、交絡(つながりが移動を抑制)か。争いなし: 学歴(educ)・年齢(age)・出生地(born)は交絡
b3 <- "educ -> city ; educ -> health ; age -> city ; age -> health ; born -> city ; born -> health ; city -> health ; educ -> inc ;"
t3 <- list(
  "所得=媒介 / つながり=媒介" = dag_parse(paste("dag {", b3, "city -> inc ; inc -> health ; city -> ties ; ties -> health }")),
  "所得=交絡 / つながり=媒介" = dag_parse(paste("dag {", b3, "inc -> city ; inc -> health ; city -> ties ; ties -> health }")),
  "所得=媒介 / つながり=交絡" = dag_parse(paste("dag {", b3, "city -> inc ; inc -> health ; ties -> city ; ties -> health }")),
  "所得=交絡 / つながり=交絡" = dag_parse(paste("dag {", b3, "inc -> city ; inc -> health ; ties -> city ; ties -> health }"))
)
show("雛形3 居住地と健康", t3, c("educ", "age", "born", "inc", "ties"), "city", "health")
sink()
cat(readLines("output/j1_templates_output.txt"), sep = "\n")
