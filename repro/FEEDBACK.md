# 如何向作者反馈复现中发现的问题

三条渠道，按"轻→重"排列。**默认只走第 1 条和第 2 条**，第 3 条留到确实需要时再用。

| 渠道 | 适用 | 地址 |
| --- | --- | --- |
| ① GitHub Issue（上游仓库） | 代码/参数/文件缺失，作者能看到也能改 | `github.com/TalhaSattar018/Chemo-elastic-phase-field-simulation-of-multi-bubble-coarsening-kinetics/issues` |
| ② 邮件给通讯作者 | 图的表述、参数确认，比公开 issue 更缓和 | 论文首页 corresponding author |
| ③ 给期刊编辑 | 仅当前两条 3–4 周无回应、且问题影响结论时 | Comput. Mater. Sci. 投稿系统 |

**注意**：不要发在自己的 fork 上（作者不会收到通知），要去 upstream 仓库开 issue。

> 作者名单中有多位中文姓名（Kunning Niu、Shan Shen、Shenglong Wang、Yongsheng Wang），
> 中文沟通大概率无障碍；若希望回复更快，可用文末的英文版，两者内容完全一致。
> **发信前请从论文首页确认通讯作者是谁**，下面按末位作者 Yongsheng Wang 起草。

---

## ① GitHub Issue（中文，可直接粘贴）

**标题**

```
复现说明：phi0_global = 0.10 无法复现论文 t = 0 的初始状态
```

**正文**

```markdown
各位作者好，

感谢公开代码与图表数据，使完整复现成为可能。

我用仓库中的源码（未作修改）重跑了 9 个 (T, σ) 组合（MATLAB R2025a，512²，
Δx = 1，Δt = 0.015，120 000 步）。模型主体复现得很好：Fig. 9 的迁移率因子
exp[−P V_act/(k_B T)] 六个数全部对到 5 位小数；压应力 > 无应力 > 拉应力的
排序在三个温度下都成立；第三阶段指数为 0.32 ± 0.02，Δr³ 拟合 R² ≥ 0.997。

有一个参数我无法与图对上，想请教实际使用的是哪个值。

### 1. `phi0_global = 0.10` 无法复现论文的初始状态

t = 0 时，发布配置给出（三个温度相同）：

| 量 | 发布配置（φ₀ = 0.10） | 论文（Fig. 2b、Fig. 3a） |
| --- | --- | --- |
| N₀ | 300 | 300 |
| r_eff,₀ = 2A/P | 3.297 | 5.9494 |
| P/A | 0.607 | 0.33617 |

气泡数一致，但气泡尺寸不一致。并且 φ₀ = 0.10 时种子无法存活：800 K 下气泡数
在 t ≈ 7.5（500 步）归零，t = 20 时 max η 由 0.97 衰减到 0.37，场均匀化到
η = 0.10；1000 K 结果相同。这与该双势阱的性质一致：f″(η) = 2A(1 − 6η + 6η²)
在 η < 0.211 时为正，平均成分 0.10 处于亚稳区。

用同一个生成函数扫描成分，φ₀ = 0.50 可以复现论文 t = 0 的三个数值，误差
< 0.75 %（N₀ = 300、r_eff = 5.9058、P/A = 0.3386）。

另有三个旁证：

* `Code.m` 中相邻两行写作 `regime = '50'; phi0_global = 0.10;`——regime 标注
  为 50 %，而成分取 0.10；
* 贵组 `.fig` 文件中保存的 η 场，自 (d) 面板起其平均值均为 0.444–0.451，
  对应守恒成分 0.45–0.50；
* 用贵组的 `measure_bubbles_refined_CH` 重新测量这些场，得到
  N = 110 / 96 / 82、r_eff = 18.15 / 20.04 / 21.82，与 Table 1 相差 0.15 %，
  说明测量函数本身没有问题。

能否确认为出图所使用的 `phi0_global`？若为 0.50，则只需修正发布文件即可。

相关一点：Figs. 1、6、8 中 t = 0 面板的平均 η = 0.1069，而同一图后续面板为
0.4437–0.4510。由于 Cahn–Hilliard 更新是守恒的，这些面板似乎来自两套不同的
设置——初始面板可能是用 0.10 的形核配置生成的。

### 2. `Code.m` 调用的三个函数不在仓库中

`make_default_disl.m`、`make_disl_dipole_stress.m`、`save_stress_maps.m` 被
`Code.m` 调用，但仓库中没有，全新 clone 运行会报 "Undefined function"。我写了
本地等价实现才能跑通。

### 3. `Code.m` 执行 18 次仿真，其中 9 次是重复的

`NO_STRESS` 在三个应力场景中各重建一次（每次完全相同），σ = 0 时的
`RESIDUAL_BIAX` 与 `NO_STRESS` 逐位相同。合计 9 次冗余，约 2.6 小时 GPU 时间。

### 4. `make_initial_eta_CH_uniform.m` 可能死循环

`min_spacing = 5.5·seedradius` 配合无出口的 `while k < numseeds`，当 300 个种子
无法在 512² 盒内按该间距排布时（seedradius ≳ 5），循环永不结束。建议改为显式
报错。

### 5. `Fig. 9 (b).xlsx` 表头与列错位

表头为 `Msigma, Tem (K)`，但行数据是 `800, 1.95419, …`。

---

我可以提交 PR 补上缺失的函数，或分享复现框架（参数文件、驱动脚本、指标脚本，
以及与数字化数据的逐项对比）。再次感谢公开数据。
```

---

## ② 邮件给通讯作者（中文，更短，适合先私下沟通）

**主题**

```
关于《Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics》中 phi0 取值的咨询
```

**正文**

```
尊敬的王老师（Yongsheng Wang 教授）：

您好。我在用贵组 GitHub 上公开的代码复现贵文（Comput. Mater. Sci. 275 (2026)
115103），大部分结果已经对上，有一个参数想先向您请教，再决定是否写成文字。

模型主体复现得很好：Fig. 9 的应力迁移率因子六个数全部一致到 5 位小数；压应力
> 无应力 > 拉应力的排序在三个温度下都成立；后期长大指数为 0.32 ± 0.02。

复现不了的是初始状态。按发布的 `phi0_global = 0.10`，300 个种子的 r_eff = 3.297、
P/A = 0.607，而 Figs. 2b/3a 给出的是 5.9494 和 0.33617；而且这些种子在 t ≈ 8
之前就消失了（成分 0.10 在该双势阱下处于亚稳区）。改用 phi0 = 0.50 后，三个
初始量都能复现，误差小于 0.75 %。

想请教：出图时实际使用的 phi0 是多少？我可以把完整的复现报告和脚本发给您。

顺颂
研安
```

---

## ③ 英文版（内容与中文版一致，需要时替换标题与正文即可）

**Subject / Title**

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

#### 1. `phi0_global = 0.10` does not reproduce the published initial state

| quantity | shipped (φ₀ = 0.10) | paper (Fig. 2b, Fig. 3a) |
| --- | --- | --- |
| N₀ | 300 | 300 |
| r_eff,₀ = 2A/P | 3.297 | 5.9494 |
| P/A | 0.607 | 0.33617 |

N₀ agrees but the bubble size does not. With φ₀ = 0.10 the seeds also do not
survive: at 800 K the population reaches zero by t ≈ 7.5 (500 steps) and max η
decays from 0.97 to 0.37 by t = 20, i.e. the field homogenises at η = 0.10; the
same happens at 1000 K. This is what one expects here, since
f″(η) = 2A(1 − 6η + 6η²) > 0 for η < 0.211.

Scanning the same generator, φ₀ = 0.50 reproduces all three published t = 0 values
to within 0.75 % (N₀ = 300, r_eff = 5.9058, P/A = 0.3386).

Three further observations point the same way: `Code.m` reads
`regime = '50'; phi0_global = 0.10;`; the η fields stored in your `.fig` files have
mean 0.444–0.451 in every panel from (d) onwards; and re-measuring those fields with
your `measure_bubbles_refined_CH` gives N = 110 / 96 / 82 and r_eff = 18.15 / 20.04 /
21.82, matching Table 1 to 0.15 %.

Could you confirm the `phi0_global` used for the figures? If it was 0.50, only the
released file needs correcting.

#### 2. Three helper functions called by `Code.m` are missing

`make_default_disl.m`, `make_disl_dipole_stress.m`, `save_stress_maps.m`.

#### 3. `Code.m` executes 18 simulations of which 9 are distinct

`NO_STRESS` is rebuilt per scenario and the σ = 0 `RESIDUAL_BIAX` case is identical
to it — about 2.6 h of redundant GPU time.

#### 4. `make_initial_eta_CH_uniform.m` can hang

`min_spacing = 5.5·seedradius` with an unbounded `while k < numseeds` loop never
terminates once 300 seeds cannot be packed (seedradius ≳ 5).

#### 5. `Fig. 9 (b).xlsx` has its columns swapped

Header says `Msigma, Tem (K)`, rows are `800, 1.95419, …`.

---

I am glad to open a PR with the missing helpers, or to share the reproduction
harness. Thanks again for making the data available.
```

---

## ④ 措辞与节奏（重要）

**要做的**

* 把"参数不一致"和"结论错误"分开说。目前所有证据都指向**文档/参数发布问题**，不是结论问题——模型本身复现得很好。
* 用「无法复现」「想请教」「似乎」，不用「错误」「造假」「自相矛盾」。
* 每条都给可验证的数字（r_eff、P/A、t 时刻），作者一看就能对上。
* 主动提供价值：缺失的 helper、复现脚本、PR。这会让回复率高很多。

**不要做的**

* 不要在 issue 里暗示学术不端。图与图之间质量不守恒这件事，写成「这些面板似乎来自两套设置」即可，让作者自己解释。
* 不要把「我们的 K_late 差 30%」当成作者的错误——那部分原因在初始条件，属讨论范畴，放在报告里即可，不必写进 issue。
* 不要在微博/知乎/X 等公开平台先发。先 issue 或邮件，给对方修正的机会。

**节奏**

1. 开 issue（①），同时把 `repro/REPORT.md` 或 `report.html` 作为链接放入。
2. 若 2 周无回应，发邮件（②）给通讯作者，附报告。
3. 若 4 周仍无回应且你认为影响他人使用，再考虑给编辑发一封简短的说明（只陈述「发布的参数无法复现图 2/3 的初态，建议作者更新仓库」，不做价值判断）。

**建议随附的材料**

* `repro/REPORT.md`（或 `report.html`）
* `repro/figures/Fig14_phi0_sensitivity.png`（一张图说清 φ₀ 的影响）
* `repro/figures/Fig11_table1_summary.png`（说明主体结果其实对得上）
