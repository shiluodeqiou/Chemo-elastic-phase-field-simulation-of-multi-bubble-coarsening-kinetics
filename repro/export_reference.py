"""Export the paper's digitised figure data to tidy CSVs for validation.

Source: Chemo_Elastic_Simulation_Data/*.xlsx (Research Data of the article).
Output: repro/reference/*.csv
"""
import csv
import os
import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Chemo_Elastic_Simulation_Data")
DST = os.path.join(ROOT, "repro", "reference")
os.makedirs(DST, exist_ok=True)


def sheet(fname):
    wb = openpyxl.load_workbook(os.path.join(SRC, fname), data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    return rows[0], rows[1:]


def dump(name, fname, header=None):
    hdr, rows = sheet(fname)
    if header is not None:
        hdr = header
    out = os.path.join(DST, name + ".csv")
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow([("" if h is None else h) for h in hdr])
        for r in rows:
            if all(v is None for v in r):
                continue
            w.writerow(["" if v is None else v for v in r])
    print(f"{name:28s} <- {fname:22s} {len(rows)} rows")


# ---- temperature series, no residual stress -------------------------------
dump("N_vs_t_noStress", "Fig. 2 (a).xlsx")
dump("r_vs_t_noStress", "Fig. 3 (a).xlsx")
dump("compactness_vs_t", "Fig. 2 (b).xlsx")
dump("r3_vs_t_stage3", "Fig. 4 (a).xlsx")
dump("r_vs_t_stage3", "Fig. 4 (b).xlsx")
dump("arrhenius_noStress", "Fig. 4 (c).xlsx")
dump("N_vs_rinv2_final", "Fig. 4 (d).xlsx")
dump("N_vs_rinv2_a", "Fig. 12 (a).xlsx")
dump("N_vs_rinv2_b", "Fig. 12 (b).xlsx")

# ---- final-state sweep ----------------------------------------------------
dump("finalN_vs_T_noStress", "Fig. 3 (b).xlsx")
dump("rate_vs_T_noStress", "Fig. 3 (c).xlsx")
dump("coalescenceEff_vs_T", "Fig. 3 (d).xlsx")

# ---- vacancy / gas fields -------------------------------------------------
dump("cv_bubble_vs_t", "Fig. 5 (a).xlsx")
dump("cv_matrix_vs_t", "Fig. 5 (b).xlsx")
dump("cg_bubble_vs_t", "Fig. 5 (c).xlsx")
dump("cg_matrix_vs_t", "Fig. 5 (d).xlsx")

# ---- compressive residual stress (-2 GPa) ---------------------------------
dump("finalN_vs_T_compressive", "Fig. 7 (a).xlsx")
dump("r_vs_t_compressive", "Fig. 7 (b).xlsx")
dump("r_vs_t_stage3_compressive", "Fig. 7 (c).xlsx")
dump("arrhenius_compressive", "Fig. 7 (d).xlsx")

# ---- tensile residual stress (+2 GPa) -------------------------------------
dump("finalN_vs_T_tensile", "Fig. 10 (a).xlsx")
dump("r_vs_t_tensile", "Fig. 10 (b).xlsx")
dump("r_vs_t_stage3_tensile", "Fig. 10 (c).xlsx")
dump("arrhenius_tensile", "Fig. 10 (d).xlsx")

# ---- Table 1 (Fig. 11) ----------------------------------------------------
dump("table1_finalN", "Fig. 11 (a).xlsx")
dump("table1_finalReff", "Fig. 11 (b).xlsx")
dump("table1_arrhenius", "Fig. 11 (c).xlsx")

# ---- mobility -------------------------------------------------------------
dump("stress_factor_vs_T", "Fig. 9 (a).xlsx")
dump("Msigma_vs_T", "Fig. 9 (b).xlsx")

print("\nDone ->", DST)
