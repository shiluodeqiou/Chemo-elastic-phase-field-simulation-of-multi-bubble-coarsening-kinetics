# 论文复现：多气泡粗化的化学-弹性相场模拟

本目录是论文

> T. Sattar, S. A. B. Gilani, S. Imran, K. Niu, S. Shen, S. Wang, Y. S. Wang,
> *Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics*,
> Computational Materials Science **275** (2026) 115103.

的独立复现框架。仓库根目录的上游 MATLAB 源码保持原样，本目录只增加驱动、记录、标定与绘图层，以及从论文图中数字化提取的对照数据。

## 快速开始

```matlab
startup_ChemoElastic            % 设置 MATLAB 路径
cd repro
run_all                         % 9 个算例：3 个温度 × 3 个应力水平（RTX 2060 上约 2.6 小时）
analyze                         % 计算指标并与论文数值对比
make_figures                    % 复现图 1-5、9、11-13
make_fig_sensitivity            % 图 14（需先跑下面的 φ₀ = 0.45 补充算例）
```

```matlab
% 可选：φ₀ = 0.45 敏感性算例（约 21 分钟）
repro_run_case(800, 0, struct('phi0', 0.45, 'tag', 'sens'));
```

首次运行前，先从论文数据集中提取对照数值：

```bash
python repro/export_reference.py       # Chemo_Elastic_Simulation_Data/*.xlsx -> repro/reference/*.csv
```

## 各文件作用

| 文件 | 作用 |
| --- | --- |
| `repro_params.m` | 论文的全部常数，并注明所属公式 |
| `repro_run_case.m` | 单个 `(T, σ)` 算例；逐行复刻 `Code.m` 的时间循环 |
| `run_all.m` | 跑完 9 个互不相同的 `(T, σ)` 组合（可断点续跑） |
| `analyze.m` | 粗化指标（`N_f`、`r_eff`、`K_late`、第三阶段指数）及与 Table 1 的对比 |
| `make_figures.m` | 复现论文图 1–5、9、11–13 |
| `make_fig_sensitivity.m` | 图 14：对初始成分的敏感性 |
| `export_reference.py` | 论文图数据 → 规整 CSV |
| `probe_all_figs.m` | 从论文 `.fig` 文件中恢复相场并重新测量（把测量管线验证到 0.15 %） |
| `calib_phi2.m` | 初始条件标定：t = 0 指标随 φ₀ 的变化 |
| `check_phi010.m` | 发布的 `phi0 = 0.10` 对种子做了什么 |
| `bench_*.m` | GPU/CPU 单步耗时与多进程共享 GPU 的测试 |
| `make_report_html.py` | 把 `REPORT.md` 渲染成单文件 `report.html` |

## 数值设置（与 `Code.m` 完全一致）

* 计算域 512² 周期性，Δx = 1，Δt = 0.015，共 120 000 步（t_end = 1800）
* 半隐式傅里叶谱格式的 Cahn–Hilliard 方程，梯度项隐式处理
* f_chem = 1.2 η²(1−η)²，κ = 4.2，本征应变 0.5 %，按 η² 标定
* 立方 2-D 弹性，C11 = 2.33，C12 = 1.5792，C44 = 1.3462（1 个求解器单位 = 77.25 GPa）
* M(T) = exp[−(0.20 eV/k_B)(1/T − 1/900)]，M(σ) = M(T)·exp[−P·V_act/(k_B T)]，
  V_act = 0.0037 nm³，P = −σ
* 残余双轴应力 σ ∈ {−2, 0, +2} GPa

`Code.m` 实际执行 18 次计算，但其中只有 **9 次互不相同**：`NO_STRESS` 在每个应力场景下重复一次，而零应力下的 `RESIDUAL_BIAX` 与 `NO_STRESS` 逐位相同。`run_all.m` 只跑这 9 个不同的算例。

## 输出

```
repro/
├── results/            case_<T>_<S>.mat   （指标 + 快照清单）      [不入库]
├── results/snapshots/  eta_istep*.mat     （微观组织场）          [不入库]
├── figures/            *.png  （200 dpi）
├── figures/data/       *.csv  （图中数据）
├── reference/          *.csv  （数字化的论文数据）
├── REPORT.md           复现报告
└── report.html         同一份报告的单文件版本
```

场快照与算例文件体积较大，已通过 `.gitignore` 排除在 git 之外。
