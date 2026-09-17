# RUN_LOG_J1 — 正式な利用資格者(著者)によるローカル再実行の記録

| 日時 | スクリプト(版) | 入力(ファイル名のみ) | 主要出力 | 本文値との照合 |
|---|---|---|---|---|
| 2026-09-05 | `j1_jlps_application.R` v2 | `jlps_all_wide.rds`(w1–w19 統合、提供版) | `results/*`(B=500, seed 20260905) | 表 2・図 2・注 1–3 の数値を転記(v0.5) |
| 2026-09-17 09:33 | `j1_check_source.R` | 統合 .dta(8,146 行 × 11,303 列; 34 列読込) | `results/j1_wording_check.txt` | 学歴・所得・成績・従業上の地位の選択肢を確認; 所得最上位区分 2,250 万円以上と被用者の定義を訂正(v0.6) |
| 2026-09-17 14:15 | `j1_check_source.R`(有効回答の定義修正後) | 統合 .dta | `results/j1_wording_check.txt` | (A) の !! を精査し §7.1 の「同一の設問」を書き換え。(B) 成績項目の実質回答は 2007: 4,655(0.970)、2011: 949(0.985)、2019: 2,308(0.969)、反復回顧報告は取れない(結論不変) |
| 2026-09-17 14:26 | `j1_jlps_application.R` v3 | `~/Documents/JLPS_data/work_jp/jlps_all_wide.rds` | `results/*`(B=500, seed 20260905, `n_success`=500) | **`j1_specs.csv`・`j1_flow.csv` は 2026-09-05 の v2 実行とバイト一致**(32 推定値・標本フロー・表 2 不変)。新規: 共通支持 25–32、働く学生除外(N=3,811)、所得の区分中点、$\mathrm{Corr}^2(E,R)=0.186$ と λ 別の補正値、図 2 の区間件数(20/28/12)。注 2・注 3 に転記(v0.7)。環境 R 4.6.0 / macOS 15.7.3 / dagmv 0.1.3 |
| 2026-09-17 20:10 | `j1_jlps_application.R` v3(出力先 `/tmp/j1_rerun`) | `~/Documents/JLPS_data/work_jp/jlps_all_wide.rds` | `/tmp/j1_rerun/*` のうち `j1_missing_shares.csv` のみ `results/` に複写 | v3 で追加した欠測割合の出力行を生成するための再実行。検証済みの `results/` を上書きしないよう出力先を分けた。値は本文 §7.1 と一致(全体で親学歴 .101、企業規模 .089; 分母は `j1_flow.csv` の `3_pos_income` = 4,751)。他の出力の一致確認は行っていない(9/17 14:26 の実行で `j1_specs.csv`・`j1_flow.csv` のバイト一致は確認済み) |
| 【v4 再実行後に SO が記入: 日時】 | `j1_jlps_application.R` v4 → `j1_freeze_record.R` | `~/Documents/JLPS_data/work_jp/jlps_all_wide.rds`(公式提供版 `…RQ102.dta` から `j1_convert_input.R` で変換) | `results/*`(v4: `j1_input_check.csv`、`j1_support.csv`・`j1_bootstrap.csv` の成績カテゴリ行を追加)、`results/j1_freeze_record.txt/.csv` | 知人査読第 3 回 R3-DC1 の凍結記録。既存 56 出力値との一致は `j1_freeze_record.txt` §5(v3 出力に対しては 56/56 一致を確認済み)。注 3 の成績カテゴリ版の値【 】を転記 |
