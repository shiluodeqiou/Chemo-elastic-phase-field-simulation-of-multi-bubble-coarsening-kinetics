# 如何向作者反馈复现中发现的问题

三条渠道，按"轻→重"排列。**默认只走第 1 条和第 2 条**，第 3 条留到确实需要时再用。

| 渠道 | 适用 | 地址 |
| --- | --- | --- |
| ① GitHub Issue（上游仓库） | 代码/参数/文件缺失，作者能看到也能改 | `github.com/TalhaSattar018/Chemo-elastic-phase-field-simulation-of-multi-bubble-coarsening-kinetics/issues` |
| ② 邮件给通讯作者 | 图的表述、参数确认，比公开 issue 更缓和 | 论文首页 corresponding author |
| ③ 给期刊 editor | 仅当前两条 3–4 周无回应，且问题影响结论时 | Comput. Mater. Sci. 投稿系统 |

**注意**：不要发在自己的 fork 上（作者不会收到通知），要去 upstream 仓库开 issue。

---

## ① GitHub Issue（英文，可直接粘贴）

**Title**

```
Reproduction note: phi0_global = 0.10 does not reproduce the published t = 0 state
```

**Body**

```markdown
Hello, and thanks for releasing the code together with the figure data — it made a
full reproduction possible.

I re-ran the nine distinct (T, σ) cases with your sources unchanged (MATLAB R2025a,
512², Δx = 1, Δt = 0.015, 120 000 steps). Most of the model reproduces very well: the
mobility factor exp[−P V_act/(k_B T)] matches Fig. 9 to five decimals, the ordering
compressive > residual-free > tensile holds at all three temperatures, and the
stage-3 exponent comes out at 0.32 ± 0.02 with Δr³ fits of R² ≥ 0.997.

One parameter I could not reconcile with the figures, and I would like to ask which
value was actually used.

### 1. `phi0_global = 0.10` does not reproduce the published initial state

At t = 0 the shipped configuration gives, for every temperature:

| quantity | shipped (φ₀ = 0.10) | paper (Fig. 2b, Fig. 3a) |
| --- | --- | --- |
| N₀ | 300 | 300 |
| r_eff,₀ = 2A/P | 3.297 | 5.9494 |
| P/A | 0.607 | 0.33617 |

N₀ agrees but the bubble size does not. With φ₀ = 0.10 the seeds also do not
survive: at 800 K the population reaches zero by t ≈ 7.5 (500 steps) and max η
decays from 0.97 to 0.37 by t = 20, i.e. the field homogenises at η = 0.10; the
same happens at 1000 K. This is what one expects for this double well, since
f″(η) = 2A(1 − 6η + 6η²) > 0 for η < 0.211.

Scanning the same generator, φ₀ = 0.50 reproduces all three published t = 0
values to within 0.75 % (N₀ = 300, r_eff = 5.9058, P/A = 0.3386).

Three further observations point the same way:

* in `Code.m` the block reads `regime = '50'; phi0_global = 0.10;` — the regime
  label suggests 50 % while the composition is 0.10;
* the η fields stored inside your `.fig` files have mean 0.444–0.451 in every
  panel from (d) onwards, i.e. a conserved composition of ≈ 0.45–0.50;
* re-measuring those same fields with your `measure_bubbles_refined_CH` gives
  N = 110 / 96 / 82 and r_eff = 18.15 / 20.04 / 21.82, matching Table 1 to
  0.15 % — so the measurement function is fine.

Could you confirm the `phi0_global` used for the figures? If it was 0.50, only the
released file needs correcting.

Related: in Figs. 1, 6 and 8 the t = 0 panel has mean η = 0.1069 whereas the later
panels of the same figure have 0.4437–0.4510. As the update conserves the mean,
these appear to come from two different set-ups — the initial panel may have been
produced with the 0.10 nucleation configuration.

### 2. Three helper functions called by `Code.m` are missing from the repository

`make_default_disl.m`, `make_disl_dipole_stress.m` and `save_stress_maps.m` are
called by `Code.m` but are not in the repo, so a fresh clone stops with
"Undefined function". I wrote local equivalents in order to run it.

### 3. `Code.m` executes 18 simulations of which 9 are distinct

`NO_STRESS` is rebuilt for each of the three stress scenarios (identical every
time) and the σ = 0 `RESIDUAL_BIAX` case is bit-identical to `NO_STRESS`. That is
nine redundant runs, ≈ 2.6 h of GPU time.

### 4. `make_initial_eta_CH_uniform.m` can hang

`min_spacing = 5.5·seedradius` combined with an unbounded `while k < numseeds`
loop never terminates once 300 seeds can no longer be packed into a 512² box
(seedradius ≳ 5). An explicit error would be safer.

### 5. `Fig. 9 (b).xlsx` has its columns swapped

The header says `Msigma, Tem (K)` but the rows are `800, 1.95419, …`.

---

I am glad to open a PR with the missing helpers, or to share the reproduction
harness (parameter file, campaign driver, metric scripts and the comparison
against the digitised data). Thanks again for making the data available.
```

---

## ② 邮件给通讯作者（更短，适合先私下沟通）

**Subject**

```
Question on phi0 in "Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics"
```

**Body**

```
Dear Prof. Wang,

I have been reproducing your paper (Comput. Mater. Sci. 275 (2026) 115103) with the
code released on GitHub, and I would like to ask one question before writing it up.

Most of the model reproduces cleanly — the stress-dependent mobility of Fig. 9 comes
out identical to five decimals, the compressive > residual-free > tensile ordering
holds at all three temperatures, and the late-stage exponent is 0.32 ± 0.02.

What I cannot reproduce is the initial state. With `phi0_global = 0.10` as released,
the 300 seeds have r_eff = 3.297 and P/A = 0.607, against 5.9494 and 0.33617 in
Figs. 2b/3a, and they dissolve within t ≈ 8 because the mean composition 0.10 is
metastable for this double well. Using phi0 = 0.50 instead reproduces all three
published t = 0 values to better than 0.75 %.

Could you tell me which value was used for the production runs? I am happy to send
the full reproduction report and the scripts.

With best regards,
```

---

## ③ 措辞与节奏（重要）

**要做的**

* 把"参数不一致"和"结论错误"分开说。目前所有证据都指向**文档/参数发布问题**，不是结论问题——模型本身复现得很好。
* 用 `does not reproduce` / `could you confirm` / `appears to`，不用 `wrong` / `incorrect` / `fabricated`。
* 每条都给可验证的数字（r_eff、P/A、t 时刻），作者一看就能对上。
* 主动提供价值：缺失的 helper、复现脚本、PR。这会让回复率高很多。

**不要做的**

* 不要在 issue 里暗示学术不端。图与图之间质量不守恒这件事，写成"这些面板似乎来自两套设置"即可，让作者自己解释。
* 不要把"我们的 K_late 差 30%"当成作者的错误——那部分原因在初始条件，属于讨论范畴，可放在报告里而不必写进 issue。
* 不要在 Twitter/X、知乎等公开平台先发。先私下/issue 沟通，给对方修正的机会。

**节奏**

1. 开 issue（①），同时把 `repro/REPORT.md` 作为附件或链接放进去。
2. 若 2 周无回应，发邮件（②）给通讯作者，附报告。
3. 若 4 周仍无回应且你认为影响他人使用，再考虑给 editor 发一封简短的 note（只陈述"发布的参数无法复现图 2/3 的初态，建议作者更新代码仓库"，不做价值判断）。

**建议随附的材料**

* `repro/REPORT.md`（或导出的 `report.html`）
* `repro/figures/Fig14_phi0_sensitivity.png`（一张图说清 φ₀ 的影响）
* `repro/figures/Fig11_table1_summary.png`（说明主体结果其实对得上）
