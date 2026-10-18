import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
LOG = RESULTS / "regression.log"
metrics = []
text = LOG.read_text() if LOG.exists() else ""

patterns = [
    ("stage6_cache_tb", r"i_misses=(\d+)\s+d_misses=(\d+)\s+writes=(\d+)"),
    ("rv32i_soc_tb", r"reference_cycles=(\d+)\s+optimized_cycles=(\d+)\s+reference_retired=(\d+)\s+optimized_retired=(\d+)"),
]
for name, pattern in patterns:
    match = re.search(pattern, text)
    row = {"test": name}
    if match:
        values = list(map(int, match.groups()))
        if name == "stage6_cache_tb":
            row.update(icache_misses=values[0], dcache_misses=values[1],
                       write_transactions=values[2])
        else:
            row.update(reference_cycles=values[0], optimized_cycles=values[1],
                       reference_retired=values[2], optimized_retired=values[3])
            row["reference_cpi"] = values[0] / values[2] if values[2] else None
            row["optimized_cpi"] = values[1] / values[3] if values[3] else None
            row["optimized_ipc"] = values[3] / values[1] if values[1] else None
    else:
        row["status"] = "not available"
    metrics.append(row)

RESULTS.mkdir(exist_ok=True)
(RESULTS / "performance.json").write_text(json.dumps(metrics, indent=2))
with (RESULTS / "performance.csv").open("w", newline="") as handle:
    fields = sorted({key for row in metrics for key in row})
    writer = csv.DictWriter(handle, fieldnames=fields)
    writer.writeheader()
    writer.writerows(metrics)
report = ["# RV32I functional performance report", "",
          "Metrics below are extracted from simulation output; no FPGA timing or resource claim is made.", ""]
for row in metrics:
    report.append("## " + row["test"])
    for key, value in row.items():
        if key != "test":
            report.append(f"- {key}: {value}")
    report.append("")
(RESULTS / "performance.md").write_text("\n".join(report))
print(json.dumps(metrics, indent=2))
