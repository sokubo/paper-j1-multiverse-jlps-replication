# J1『理論と方法』— 実証節(§7)の再現経路 / Reproduction path for the JLPS analysis

対象原稿: 「何を統制すべきか――「頑健性」を候補因果グラフで分解する」v0.9(2026-09-17; v0.8 の題名「候補因果グラフで読み解く多元宇宙分析」、v0.6 までの題名「回顧的な中学成績を統制すべきか…」)。
英語 companion(Okubo 2026, arXiv:2609.16618)の公開リポジトリ `paper-multiverse-dag-replication` とも、汎用パッケージ `dagmv` とも別物であり、
J1 の数値はすべてここに記す経路で生成される。**J1 専用の公開アーカイブ**: https://github.com/sokubo/paper-j1-multiverse-jlps-replication
(固定版はタグ `j1-v1.0`(v0.9 の改訂版; v1.0 の差は補助スクリプト `j1_freeze_record.R`・図の凡例 `j1_fig_helpers.R`・文書のみで、分析コードと出力は不変); 公開・タグ付けの手順は `github/make_replication_archives.sh` と `github/publish_replication.sh`、
クリーンコピーでの合成データ再実行の記録は同アーカイブの `RELEASE_CHECK.md`)。

## 1. データと利用条件 / Data and access
- 入力: 東大社研・若年壮年パネル調査(JLPS-Y/M 2007 開始; 2011 追加標本; 2019 リフレッシュ標本)の**個票**(第 1–19 波を統合した Stata ファイル、8,146 行 × 11,303 列。変換後の RDS は `cohort`・`entry`・`source_file` の 3 列が加わって 11,306 列で、`j1_freeze_record.txt` はこちらの寸法を記録する)。本稿が使う変数は下記 2 節の 34 列のみ。分析に用いるのは **2007 年第 1 波・2011 年第 5 波・2019 年第 13 波**(提供版の波番号)である。
- **この統合ファイルの来歴(第 3 回 R3-DC1 / 資料依頼 2 への回答)**: 本稿が用いたのは**調査プロジェクト内で研究参加者に配布された統合版**であり、SSJDA に利用申請して受け取った公開提供版ではない。したがって **SSJDA の調査番号は付かない**。版の識別は統合ファイル名の末尾番号(`…RQ102.dta`)と、`j1_freeze_record.R` が `results/j1_freeze_record.txt` に書き出す SHA-256 による(この記録はタグ付けの前にライセンス機で生成する)。
- **第三者が同じ三波を入手する経路**: SSJDA の公開提供版を申請する。本稿の三波に対応するのは **調査番号 PY130「東大社研・若年パネル調査(JLPS-Y)wave1-13, 2007-2019」**(doi:10.34500/SSJDA.PY130; 2011 追加標本は `PY130_add2`、2019 リフレッシュ標本は `PY130_refresh` として収録)と **調査番号 PM130「東大社研・壮年パネル調査(JLPS-M)wave1-13, 2007-2019」**(doi:10.34500/SSJDA.PM130)。いずれも 2023-10-27 公開、申請と承認が必要(ダウンロード提供)。**版が異なるため回答者数や整形が本稿の統合版と一致する保証はない**(本稿の提供版では 2019 リフレッシュ標本の第 1 波が 2,383 人、仲・三輪 2020 の分析対象版は 2,380 人)。数値をバイト単位で再現するには本稿と同じ統合版が必要で、公開提供版からの再現は「同じ設計・同じ変数定義での再分析」になる。
- 参考: CSRDA は JLPS-Y 第 1 波の**教育用の疑似データ**を無制限公開している(調査番号 PY010 をもとに 1,000 ケースを無作為抽出し変数を大幅に削減、回答にノイズを付加)。本稿のコードが使う 34 列は揃っていないため**そのままでは動かず**、CSRDA 自身も「二次分析の結果は、学術的な実証研究の結果とみなすことはできません」としている。動作確認には本アーカイブの合成データを使う。
- 個票は提供条件により **権限を与えられた著者のローカル機でのみ**扱う。個票・個票由来の中間ファイルはこのアーカイブにも公開リポジトリにも含めない。集計出力は **セル N < 10 を秘匿**したうえで `results/` に置く(秘匿だけで公開許可が確定するわけではなく、当該調査とデータ提供元の条件に従う)。**個票の公開・再配布は行わない。**
- **統合ファイルから分析用 RDS への変換**は `j1_convert_input.R`(= プロジェクト共通の `paper/jp/jp_combine_wide.R` の写し)が行う。内容は読み込み(`haven::read_dta`)、変数名の小文字化、ラベル付き値の数値化、`cohort`/`entry` 列(統合ファイルでは NA; 初回回答波は `j1_jlps_application.R` が判定)と `source_file` 列の付加、`saveRDS` のみで(複数ファイルを渡したときの縦結合以外に)結合・整形はしない。`Rscript j1_convert_input.R <out.rds> <統合 .dta>`。
- **入力検査**(v4): `j1_jlps_application.R` は個人 ID(`panelid`)の一意性と標本割当の排他性を `stopifnot` で検査し、使用列の値域(最小・最大・非欠測数)を標準出力と `results/j1_input_check.csv` に出す(個票は出さない)。
- 動作確認用の**合成データ** `analysis/synthetic/j1_synth_wide.rds`(`j1_make_synthetic.R` が生成; 変数名と符号のみ実データに合わせた乱数)と、その出力 `analysis/synthetic_out/`。合成データの実行は **動作確認であって JLPS の数値の再現ではない**。

## 2. 変数辞書とリコード規則 / Variable dictionary and recodes(`j1_jlps_application.R` の `pick()`・後続行に対応)
| 概念 | 2007 w1 | 2011 w5 | 2019 w13 | リコード |
|---|---|---|---|---|
| コホート(初回調査) | zq50/zq03/zq23a のいずれかに回答 | dq43/dq02/dq69a | lq44re_2/lq02/lq72a | 先に該当した初回波に割当(2007 → 2011 → 2019 の順; 未割当 0) |
| 本人学歴 | zq23a | dq69a | lq72a | 「最後に通った学校」1=中学…6=大学院; 7=わからない・9=無回答 → 欠測。**処置 univ = (5 大学, 6 大学院)**。設問は卒業・在学・中退を区別しない。 |
| 中 3 成績(回顧) | zq17 | dq61 | lq65 | 1=上の方…5=下の方 → 6−値(高いほど良い); 6=わからない・9=無回答 → 欠測 |
| 父学歴 / 母学歴 | zq23c / zq23d | dq69c / dq69d | lq72b / lq72c | 1–6 のみ有効(7・9 → 欠測)。**peduc = 両親の最大値**; 片親のみ有効ならその値、両方欠測なら欠測。回帰にはカテゴリ(因子)として投入 |
| 婚姻 | zq50 | dq43 | lq44re_2(欠測なら lq44) | w1: 1=未婚 2=既婚 3=死別 4=離別 → married = (値 == 2); w5/w13: 1=既婚(事実婚を含む文言) → married = (値 == 1)。1–4 以外 → 欠測 |
| 本人年収 | zq47a | dq35a | lq37a | 13 区分。**区分代表値**(選択肢に印字された「〜くらい」の値): 1=なし→0(所得正の条件で除外), 2=25万円未満→12.5, 3→50, 4→100, 5→200, 6→300, 7→400, 8→500, 9→700, 10→1000, 11→1500, 12→2000, 13=2,250 万円以上→2500(開区間); 14=わからない・99 → 欠測。感度: 区間中点(4→112.5, 8→525, 9→725, 10→1050; 他は同じ)、最上位 2,250・3,750(1,875 は下限未満の域外ストレス値)。結果 = log(万円) |
| 従業上の地位 | jc_1 | dq03_1 | lq03_1 | **被用者 = 2 正社員, 3 パート等, 4 派遣, 5 請負, 12 学生(非正規で就業)**; regular = (値 == 2)。感度: 12 を除外 |
| 職業 | jc_2 | dq03_2 | lq03_2 | 1–8, 10 を因子; 9=わからない → 欠測 |
| 企業規模 | jc_6 | dq03_7 | lq03_7 | 1–9 を因子(9 = 官公庁を含む; 順序尺度としては扱わない); 10=わからない → 欠測 |
| 年齢 | 調査年 − ybirth | 同 | 同 | 出生月不使用。分析 25–45。2019 コホートは 21–32(仲・三輪 2020 の「2018-01-01 時点 20–31 歳」に対応)、分析標本では 25–32。**共通支持の分析は 25–32(本文 注 2)**; 25–31 は補足(`j1_support.csv`・`j1_bootstrap.csv` の `*_25_31` 行) |
| 性別 | sex | | | female = (sex == 2) |

分析標本: 25–45 歳 → 被用者 → 所得正 → 許容仕様に必要な変数(univ, grades, peduc, married, age, female)が完全(最大標本 4,180)→ 争点 5 変数まで完全(主分析 3,832)。標本フローは `results/j1_flow.csv`。

## 3. 候補グラフと許容仕様の対応表 / Candidate graphs and admissibility
- DAG 定義は `j1_jlps_application.R` の `base`, `gr_conf`, `gr_desc`, `gr_mix`, `ma_coll`, `ma_prec`(W1–W5)と診断世界(W5′, D1, D2)。
- 妥当性は dagmv `adjustment_valid()`(一般化調整基準)を 32 仕様 × 5 世界で直接評価。結果は `results/j1_validity.csv`(データに依存しないので合成データ実行と同一)、役割分類は `results/j1_roles.csv`、診断世界は `results/j1_world_diagnostics.csv`。

## 4. 実行順・環境・乱数 / Run order, environment, seeds
```sh
cd paper/jp/J1-rironhoho/analysis
Rscript j1_convert_input.R <jlps_all_wide.rds> <統合 .dta>        # 提供版(統合 .dta) → 分析用 RDS(プロジェクト外に保存; 読込・小文字化・数値化・保存のみ)
Rscript j1_check_source.R <統合 .dta> ../results                  # 設問文言・選択肢・分布の照合ログ (results/j1_wording_check.txt), 反復回顧の有無 (B), 本文の 2 文の可否 (C)
Rscript j1_jlps_application.R <jlps_all_wide.rds> ../results     # 入力検査・32 仕様・分解・ブートストラップ・感度・図 (下記の出力一覧; 約 25 分)
Rscript j1_make_figures.R ../results ../results                  # results/ の集計値から図 1・図 2 を再描画(個票不要; 第 2 引数を ../figures にすると原稿用の採用版を書く)
Rscript j1_templates.R                                           # §6 雛形 1–3 の役割分類表 → output/j1_templates_output.txt(データ不要)
Rscript j1_freeze_record.R <jlps_all_wide.rds> ../results [<統合 .dta>] [<実行した変換スクリプト>]  # 凍結記録: 入力の識別・コードの SHA-256・環境・出力の SHA-256・図の対応(results/ 描画・figures/ 採用版・Word 埋込)・変換スクリプトの照合・本文 61 値との照合 → results/j1_freeze_record.txt/.csv(.dta と変換スクリプトは省略可)
```
合成データでの動作確認(個票不要; **JLPS の数値の再現ではない**): `Rscript j1_make_synthetic.R && Rscript j1_jlps_application.R synthetic/j1_synth_wide.rds synthetic_out`。
Linux では日本語ラベルのために `LC_ALL=C.UTF-8` を付ける(macOS は不要)。図の PNG は描画フォントに依存し(macOS = Hiragino Sans、Linux = Noto Sans CJK JP)、画素の一致はプラットフォーム内でのみ期待できる。原稿に採用した `figures/` の 2 図と、実行時に `results/` に描かれた 2 図、Word に埋め込まれた画像の対応(SHA-256)は凍結記録の 4b 節に記録する(v1.0; 知人査読第 4 回 R4-m3)。
- 環境: R ≥ 4.3、`data.table`、`dagmv`(≥ 0.1.3; `remotes::install_github("sokubo/dagmv@v0.1.3")`)、`haven`(check_source のみ)。実行環境の `sessionInfo()` は `results/j1_sessionInfo.txt`。
- 乱数: `SEED = 20260905`、ブートストラップ `B = 500`(環境変数 `J1_B` で変更可)。個人単位・コホート内層化の再標本化; 区間はパーセンタイル(q025, q975)、SE はブートストラップ SD。`j1_bootstrap.csv` の `n_success` は**その行の標本・統計量について有限だった反復数**(v4; v3 まではプール 32 仕様の成功反復数を全行に複写していた。その値は `n_all32_finite_pooled` 列に残す)。成績カテゴリ版のブートストラップ(`pooled_25_45_grades_categorical` 行)は乱数種を戻して**同じ再標本**を使うので、線形得点版との差の行 `delta_contrast_linear_minus_categorical` は対応のある区間である。
- 標準誤差: HC1(不均一分散に頑健、クラスタなし)。抽出地点の識別子は提供版になく、ブートストラップも地点内相関は回復しない。
- 秘匿: `MIN_CELL = 10`; N < 10 のセルは NA。

## 5. 出力と本文の対応 / Output map
| 出力(`results/`) | 内容 | 本文 |
|---|---|---|
| `j1_flow.csv` | 標本フロー(段階 × コホート; N・大学在籍率・女性率・年齢範囲) | 注1、§7.1 |
| `j1_descriptives.csv` | 分析標本の記述統計 | §7.1 |
| `j1_specs.csv` | 32 仕様の推定値・HC1 SE・p・許容する世界 | 図 2、§7.2 |
| `j1_validity.csv` | 32 仕様 × W1–W5 の許容仕様の対応表 | 表 1、§7.1 |
| `j1_roles.csv`, `j1_world_diagnostics.csv` | 役割分類、診断世界 | 表 1、§6.1 |
| `j1_decomp.txt`, `j1_unlicensed.csv`, `j1_implicit_weights.csv` | 素朴・世界別指標、ρ、暗黙の重み(3/8, 1/8, 3/8, 1/8) | 表 2 |
| `j1_bootstrap.csv` | 世界間対比・婚姻対比・世界別平均・ρ のブートストラップ(プール、コホート別、共通支持 25–32、補足 25–31; v4 は成績カテゴリ版の行を追加) | 表 2 対比行、§7.2、注2 |
| `j1_by_cohort.csv` | コホート別の世界別平均 | §7.2 |
| `j1_support.csv` | 共通支持 25–32(と 25–31)、最大標本、働く学生除外、所得区間中点、コホート別年齢範囲 | 注2、注3、§7.1 |
| `j1_income_sens.csv` | 最上位区分の割当感度 | 注3 |
| `j1_fig_checks.txt` | 図 2 の区間比較の件数(28 仕様中 0.168 を含まない件数など)を出力値から算出 | §7.2 |
| `j1_measurement_calibration.csv` | 統制変数で残差化した E・R の相関二乗と、λ ごとの 2 パラメータ補正値 | §7.2(較正) |
| `j1_wording_check.txt` | 設問・選択肢の三波比較、反復回顧の有無 | §7.1 |
| `j1_missing_shares.csv` | 分析標本に入る前の欠測割合(全体・コホート別) | §7.1「親学歴(欠測 10%)・企業規模(同 9%)」 |
| `j1_input_check.csv` | 行数・ID の一意性・標本割当(v4) | §7.1 |
| `j1_support.csv` の `main_sample_grades_categorical` 行、`j1_bootstrap.csv` の `*_grades_categorical` 行 | 成績を 4 自由度のカテゴリ変数にした許容 4 仕様と、対応のあるブートストラップ(v4, R3-O1) | 注 3 |
| `j1_freeze_record.txt/.csv` | 凍結記録(入力の識別・コードと出力の SHA-256・環境・本文値との照合) | `RUN_LOG_J1.md` |
| `j1_fig_dag.png`, `j1_fig_specmap.png` | 図 1、図 2 | |

表 2 の「頑健性比」は 平均 ÷ √(SE² の平均 + モデリング SD²)(dagmv `mv_decompose()`; SE² の平均であって平均 SE の二乗ではない)。

## 6. 版と検証 / Versions and verification
- `j1_jlps_application.R` v4(2026-09-17, 知人査読第 3 回): v3 との差は、入力検査、`n_success` の行ごとの定義、成績カテゴリ版の感度と対応のあるブートストラップ。**32 推定値・分解・ブートストラップの定義は変えていない**(合成データで `j1_specs.csv`・`j1_flow.csv`・`j1_decomp.txt`・`j1_by_cohort.csv`・`j1_income_sens.csv`・`j1_validity.csv`・`j1_roles.csv` がバイト一致、`j1_bootstrap.csv` の共通 61 データ行も一致することを確認; v3 = `j1_jlps_application_v3_backup.R`)。**実データでも同じ**: 2026-09-17 の v4 再実行では 15 ファイルが v3 実行とバイト一致し、増えたのは `j1_input_check.csv` と成績カテゴリ版の 5 行(bootstrap, 61→66 データ行)・4 行(support, 51→55 データ行)のみ(`RUN_LOG_J1.md`)。
- `j1_jlps_application.R` v3(2026-09-17): v2 との差は、許容仕様の対応表・区分代表値と中点・働く学生除外・成功反復数と区間方式・図 2 の出力値照合・測定較正量・sessionInfo の追加(v2 = `j1_jlps_application_v2_backup.R`)。
- **v4 のローカル再実行(2026-09-17 23:28–23:29)**: `j1_specs.csv`・`j1_flow.csv`・`j1_decomp.txt`・`j1_by_cohort.csv`・`j1_income_sens.csv`・`j1_fig_checks.txt`・`j1_measurement_calibration.csv` は v3 実行とバイト一致。v4 が足したのは `j1_input_check.csv` と、成績カテゴリ版の 5 行(`j1_bootstrap.csv`)・4 行(`j1_support.csv`)のみ。注 3 の値は原稿 v0.9 に転記した。
- `j1_check_source.R` v2: 旧版の単一交絡近似 $0.245-0.077/\lambda$ の分岐を削除し、末尾の開示に関する結語を「集計値であることだけでは公開可能とならない」に訂正。`j1_templates.R` v2: 雛形 1 を本文 v0.8 の W1–W5 に更新(旧版は `j1_templates_v1_backup.R`)。`j1_make_synthetic.R` v2: 出力先を引数で指定可。
- `synthetic_out/` は v4 の全出力(B = 500)。`j1_worked_example.R` は §5 の説明用シミュレーションで、本文の数値は生成しない。
- **開示**: `results/` は個票を含まず N < 10 のセルを伏せた集計値だが、**それだけで公開可能とはならない**。公開アーカイブへの収録は当該調査とデータ提供元の利用条件と当該調査の条件に照らした開示確認の後に行う(確認前は `results/`・`figures/` を公開アーカイブから除く; `make_replication_archives.sh` の `J1_INCLUDE_RESULTS=1`)。 **第三者(著者以外のデータへのアクセスを持つ利用者)による JLPS 個票での再実行は行われておらず、実データの再現は著者のローカル実行記録(`RUN_LOG_J1.md`、`results/j1_freeze_record.txt`)による。**
- `j1_freeze_record.R` v1.0(2026-09-20, 知人査読第 4 回 R4-m3): 4b 節(図の来歴: `results/`・`figures/`・Word 埋込画像の SHA-256 と一致判定)、4c 節(実行した変換スクリプト `jp_combine_wide.R` と同梱 `j1_convert_input.R` を `##` コメント行を除いて照合——両者の差はヘッダのコメントのみ)を追加し、本文値の照合を v1.0 の 61 値に更新(v0.9 で照合していた「媒介変数 3 つを統制した係数 0.061」の文を本文から削除したため 1 値減)。`j1_fig_helpers.R` v1.0: 凡例の用語を本文に合わせて「許容」「回顧報告=到達地位の子孫」に統一(描画データは不変)。公開タグ `j1-v0.9` の同梱 `j1_freeze_record.R` は引数順の古い版で、凍結記録を作った版と一致していなかった——v1.0 のタグで補助スクリプトと使用法と記録を一致させる。
- 著者(権限を与えられた利用者)によるローカル再実行の日時と本文値との照合は `RUN_LOG_J1.md` に記録する。

**`j1_missing_shares.csv` について**: この出力行はスクリプト v3 に 2026-09-17 の実行後に加えたため、同日の実行では書かれなかった。**2026-09-17 に別の出力先へ再実行して生成し、このファイルだけを `results/` に複写した**(`RUN_LOG_J1.md`)。値は本文 §7.1 の記述と一致する:

| 変数 | 全体 | 2007 | 2011 | 2019 |
|---|---:|---:|---:|---:|
| 親学歴 `peduc` | .101 | .105 | .096 | .094 |
| 企業規模 `firm` | .089 | .084 | .076 | .107 |
| 成績 `grades` | .022 | .023 | .007 | .026 |
| 職業 `occ` | .005 | .007 | .001 | .003 |
| 婚姻 `married` | .004 | .000 | .004 | .012 |
| 大学在籍 `univ` | .003 | .001 | .001 | .007 |
| 雇用形態 `regular` | .000 | .000 | .000 | .000 |

分母は `j1_flow.csv` の段階 `3_pos_income`(全体 4,751)。本文の「親学歴(欠測 10%)・企業規模(同 9%)」はこの全体列である。検証済みの `results/` を上書きせずに再生成するには、別の出力先に走らせてから複写する:

```sh
cd paper/jp/J1-rironhoho/analysis
Rscript j1_jlps_application.R ~/Documents/JLPS_data/work_jp/jlps_all_wide.rds /tmp/j1_rerun
cp /tmp/j1_rerun/j1_missing_shares.csv ../results/
```

このファイルはスクリプト 117 行目、ブートストラップより前に書かれるので実行開始 1 分以内に生成される。
