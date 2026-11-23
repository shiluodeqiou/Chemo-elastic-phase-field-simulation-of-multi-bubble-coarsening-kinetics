# Reproducing *Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics*

This folder is a self-contained reproduction harness for

> T. Sattar, S. A. B. Gilani, S. Imran, K. Niu, S. Shen, S. Wang, Y. S. Wang,
> *Chemo-elastic phase-field simulation of multi-bubble coarsening kinetics*,
> Computational Materials Science **275** (2026) 115103.

The upstream MATLAB sources in the repository root are used unmodified; this
folder adds the driving, bookkeeping, calibration and plotting layer, plus the
digitised reference data extracted from the published figures.

## Quick start

```matlab
startup_ChemoElastic            % set the MATLAB path
cd repro
run_all                         % 9 cases: 3 temperatures x 3 stress levels  (~2.6 h on an RTX 2060)
analyze                         % metrics + comparison with the published values
make_figures                    % regenerate figures 1-5, 9, 11, 12
```

Before the first run, extract the reference values from the article's data set:

```bash
python repro/export_reference.py       # Chemo_Elastic_Simulation_Data/*.xlsx -> repro/reference/*.csv
```

## What each file does

| file | role |
| --- | --- |
| `repro_params.m` | every constant of the paper, with the equation it belongs to |
| `repro_run_case.m` | one `(T, σ)` realisation; line-by-line reproduction of the `Code.m` time loop |
| `run_all.m` | the nine distinct `(T, σ)` pairs of the campaign (resumable) |
| `analyze.m` | coarsening metrics (`N_f`, `r_eff`, `K_late`, stage-3 exponent) and the comparison with Table 1 |
| `make_figures.m` | figures 1–5, 9, 11, 12 of the article |
| `export_reference.py` | digitised figure data → tidy CSV |
| `probe_all_figs.m` | recovers the phase fields stored inside the article's `.fig` files and re-measures them |
| `calib_*.m` | initial-condition calibration experiments (see `REPORT.md`) |

## Numerical set-up (identical to `Code.m`)

* domain 512² periodic, Δx = 1, Δt = 0.015, 120 000 steps (t_end = 1800)
* semi-implicit Fourier spectral Cahn–Hilliard, gradient term implicit
* f_chem = 1.2 η²(1−η)², κ = 4.2, eigenstrain 0.5 % scaled by η²
* cubic 2-D elasticity, C11 = 2.33, C12 = 1.5792, C44 = 1.3462 (1 unit = 77.25 GPa)
* M(T) = exp[−(0.20 eV/k_B)(1/T − 1/900)], M(σ) = M(T)·exp[−P V_act/(k_B T)],
  V_act = 0.0037 nm³, P = −σ
* residual biaxial stress σ ∈ {−2, 0, +2} GPa

`Code.m` actually executes 18 runs, but only **nine are distinct**: the
`NO_STRESS` mode is repeated for every stress scenario and the zero-stress
`RESIDUAL_BIAX` case is bit-identical to `NO_STRESS`. `run_all.m` runs the nine
distinct cases only.

## Outputs

```
repro/
├── results/            case_<T>_<S>.mat   (metrics + snapshot list)   [not tracked]
├── results/snapshots/  eta_istep*.mat     (microstructure fields)     [not tracked]
├── figures/            *.png  (200 dpi)
├── reference/          *.csv  (digitised published data)
└── REPORT.md           reproduction report
```

Field snapshots and case files are large and are excluded from git via
`.gitignore`.
