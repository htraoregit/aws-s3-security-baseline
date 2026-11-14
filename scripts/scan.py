"""Save Checkov's full report and reject failures or undocumented exceptions."""
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED_SKIPS = {
    ("CKV_AWS_144", "aws_s3_bucket.demo"),
    ("CKV2_AWS_62", "aws_s3_bucket.demo"),
    ("CKV_AWS_145", "aws_s3_bucket.logs"),
    ("CKV_AWS_18", "aws_s3_bucket.logs"),
    ("CKV_AWS_144", "aws_s3_bucket.logs"),
    ("CKV2_AWS_62", "aws_s3_bucket.logs"),
}


def accepted(report):
    summary = report["summary"]
    skips = {(c["check_id"], c["resource"]) for c in report["results"]["skipped_checks"]}
    return (summary["failed"] == 0 and summary["parsing_errors"] == 0
            and summary["passed"] > 0 and summary["checkov_version"] == "3.4.3"
            and skips == EXPECTED_SKIPS and summary["skipped"] == len(EXPECTED_SKIPS))


def main():
    out = ROOT / "evidence"
    out.mkdir(exist_ok=True)
    result = subprocess.run(
        [sys.executable, "-m", "checkov.main", "-d", str(ROOT), "--framework", "terraform",
         "--skip-download", "--output", "json"], capture_output=True, text=True, cwd=ROOT)
    (out / "current-scan.json").write_text(result.stdout, encoding="utf-8")
    (out / "current-scan.stderr.txt").write_text(result.stderr, encoding="utf-8")
    report = json.loads(result.stdout)
    passed = result.returncode == 0 and accepted(report)
    record = {"recorded_at_utc": datetime.now(timezone.utc).isoformat(),
              "checkov_exit_code": result.returncode, "gate_passed": passed,
              "summary": report["summary"],
              "skips": sorted([list(s) for s in EXPECTED_SKIPS])}
    (out / "scan-summary.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
