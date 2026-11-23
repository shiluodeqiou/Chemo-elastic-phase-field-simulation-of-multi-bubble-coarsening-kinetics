This repository contains the MATLAB source code and supporting functions used in the study “Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics.” The supporting CSV data files are uploaded separately in the submission portal’s Research Data section. The repository is intended to support reproducibility of the computational workflow and figure generation.

---

## Reproduction

`repro/` contains an independent reproduction harness for the article: it drives the
sources above unmodified, runs the nine distinct (temperature, residual-stress)
realisations of the campaign, recomputes every metric with the original
measurement function, and compares the results with the digitised published data.

* **[`repro/REPORT.md`](repro/REPORT.md)** — reproduction report: verdict,
  quantitative comparison with Table 1 / Figs. 2–12, and the discrepancies found
  between the released code, the published figures and the manuscript.
* **[`repro/report.html`](repro/report.html)** — the same report as a single
  self-contained page (figures embedded).
* **[`repro/README.md`](repro/README.md)** — how to run it.

Headline numbers from the reproduction (see the report for the full tables):

| quantity | result |
| --- | --- |
| stress mobility factor exp[−P V_act/(k_B T)] (Fig. 9) | reproduced exactly, 6/6 values to 5 decimals |
| stress ranking compressive > none > tensile | reproduced at all three temperatures |
| late-stage Δr³ ∝ t, stage-3 exponent | reproduced, n = 0.32 ± 0.02 (LSW 1/3) |
| Table 1 final radius | +7.6 % ± 1.2 % |
| Table 1 final bubble count | −21 % (systematic, traced to the undocumented initial composition) |

```matlab
startup_ChemoElastic
cd repro
run_all            % 9 cases, ~170 min on an RTX 2060
analyze            % comparison with the published values
make_figures       % figures 1-5, 9, 11-13
```

> **Note on the initial condition.** `Code.m` ships `phi0_global = 0.10`, which is
> metastable for this double well — the bubbles dissolve and no coarsening occurs.
> The production runs behind the published figures used a mean composition of
> ≈ 0.45–0.50 (`repro/repro_params.m` explains the calibration). If you reuse this
> code, set the composition explicitly.
