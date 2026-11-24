多气泡粗化动力学的化学-弹性相场模拟
======

本仓库包含论文《Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics》所用的 MATLAB 源码与支撑函数。配套的 CSV 数据文件在投稿系统的 Research Data 部分单独上传。仓库用于支持计算流程的复现与出图。

---

## 复现

`repro/` 是一套独立的复现框架：在不改动上游源码的前提下驱动计算，跑完 9 个（温度 × 残余应力）算例，用原作者的测量函数重新计算全部指标，并与论文中数字化提取的数据逐项对比。

* **[`repro/REPORT.md`](repro/REPORT.md)** —— 复现报告：结论、与 Table 1 / 图 2–12 的定量对比，以及代码、图与正文之间不一致之处的说明。
* **[`repro/report.html`](repro/report.html)** —— 同一份报告的单文件版本（图片内嵌，浏览器直接打开）。
* **[`repro/README.md`](repro/README.md)** —— 运行方法与文件清单。

主要结果（完整表格见报告）：

| 项目 | 结果 |
| --- | --- |
| 应力相关迁移率因子 exp[−P·V_act/(k_B T)]（图 9） | 精确复现，6 个数全部对到 5 位小数 |
| 压应力 > 无应力 > 拉应力 的排序 | 三个温度全部成立 |
| 后期 Δr³ ∝ t、第三阶段指数 | 复现，n = 0.32 ± 0.02（LSW 理论值 1/3） |
| Table 1 最终半径 | +7.6 % ± 1.2 % |
| Table 1 最终气泡数 | −21 %（系统性偏差，源于复现所选的初始成分） |
| 质量守恒 | 漂移 ≤ 2.3 × 10⁻⁶ |

```matlab
startup_ChemoElastic
cd repro
run_all            % 9 个算例，RTX 2060 上约 170 分钟
analyze            % 与论文数值逐项对比
make_figures       % 复现图 1-5、9、11-13
```

> **关于初始条件。** `Code.m` 中 `phi0_global = 0.10`，该成分在此双势阱下处于亚稳区：种子在 t ≈ 8 之前即不再存活，无法复现论文 t = 0 的状态（r_eff = 5.9494、P/A = 0.33617）。本复现取 φ₀ = 0.50，按上述已发表数值标定，推导见 `repro/REPORT.md` 第 3 节。若复用此代码，请显式设定成分。
