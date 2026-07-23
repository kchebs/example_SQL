"""NL2SQL golden eval: map questions, optionally execute against Postgres, write artifact.

Offline-first: when Postgres is unreachable, validate mapped SQL is non-empty and
matches expected patterns. Prefer live execution when Docker/local DB is up.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from nl2sql.mapper import map_question_to_sql

REPO_ROOT = Path(__file__).resolve().parent.parent
GOLDEN_PATH = Path(__file__).resolve().parent / "golden.json"
DEFAULT_ARTIFACT = REPO_ROOT / "artifacts" / "nl2sql_eval.json"
DEFAULT_DB_URL = "postgresql://example:example@127.0.0.1:5432/example_sql"


def _load_golden() -> list[dict[str, Any]]:
    with GOLDEN_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list) or not data:
        raise ValueError(f"golden file empty or invalid: {GOLDEN_PATH}")
    return data


def _sql_matches_expected(sql: str, case: dict[str, Any]) -> tuple[bool, str]:
    sql_norm = " ".join(sql.split())
    sql_lower = sql_norm.lower()

    if "expected_sql" in case and case["expected_sql"] is not None:
        expected = " ".join(str(case["expected_sql"]).split())
        if sql_norm.lower() != expected.lower():
            return False, "mapped SQL does not equal expected_sql"
        return True, "exact expected_sql match"

    contains = case.get("expected_sql_contains") or []
    if not contains:
        if not sql.strip():
            return False, "empty SQL"
        return True, "non-empty SQL (no pattern checks)"

    missing = [frag for frag in contains if frag.lower() not in sql_lower]
    if missing:
        return False, f"missing expected fragments: {missing}"
    return True, "expected_sql_contains matched"


def _db_url() -> str:
    return os.environ.get("EXAMPLE_SQL_DATABASE_URL") or DEFAULT_DB_URL


def _try_psql(sql: str) -> tuple[bool, str]:
    """Execute SQL via psql. Returns (ok, detail)."""
    url = _db_url()
    if not _which("psql"):
        return False, "psql not found"

    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as tmp:
        tmp.write(sql if sql.rstrip().endswith(";") else sql + ";\n")
        tmp_path = tmp.name
    try:
        proc = subprocess.run(
            [
                "psql",
                url,
                "-v",
                "ON_ERROR_STOP=1",
                "-t",
                "-A",
                "-f",
                tmp_path,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "psql failed").strip()
            return False, err[:500]
        return True, (proc.stdout or "").strip()[:500] or "executed OK"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def _try_docker_psql(sql: str) -> tuple[bool, str]:
    """Execute SQL via docker compose exec db psql."""
    compose: Optional[list[str]] = None
    if _which("docker"):
        # Prefer `docker compose` plugin
        check = subprocess.run(
            ["docker", "compose", "version"],
            capture_output=True,
            cwd=str(REPO_ROOT),
        )
        if check.returncode == 0:
            compose = ["docker", "compose"]
        elif _which("docker-compose"):
            compose = ["docker-compose"]

    if not compose:
        return False, "docker compose unavailable"

    # Quick health: is the db container up?
    ps = subprocess.run(
        compose + ["ps", "--status", "running", "-q", "db"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        timeout=15,
    )
    if ps.returncode != 0 or not (ps.stdout or "").strip():
        return False, "docker db service not running"

    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False) as tmp:
        tmp.write(sql if sql.rstrip().endswith(";") else sql + ";\n")
        tmp_path = tmp.name
    try:
        with open(tmp_path, encoding="utf-8") as sql_in:
            proc = subprocess.run(
                compose
                + [
                    "exec",
                    "-T",
                    "db",
                    "psql",
                    "-U",
                    "example",
                    "-d",
                    "example_sql",
                    "-v",
                    "ON_ERROR_STOP=1",
                    "-t",
                    "-A",
                ],
                stdin=sql_in,
                capture_output=True,
                text=True,
                cwd=str(REPO_ROOT),
                timeout=30,
            )
        if proc.returncode != 0:
            err = (proc.stderr or proc.stdout or "docker psql failed").strip()
            return False, err[:500]
        return True, (proc.stdout or "").strip()[:500] or "executed OK"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


def _which(cmd: str) -> bool:
    from shutil import which

    return which(cmd) is not None


def probe_db() -> tuple[str, bool]:
    """Detect execution backend. Returns (mode, available).

    mode is one of: docker_psql, psql, offline
    """
    # Prefer docker when compose db is already up (smoke.sh path).
    ok, detail = _try_docker_psql("SELECT 1;")
    if ok:
        return "docker_psql", True
    ok, detail = _try_psql("SELECT 1;")
    if ok:
        return "psql", True
    return "offline", False


def execute_sql(sql: str, mode: str) -> tuple[bool, str]:
    if mode == "docker_psql":
        return _try_docker_psql(sql)
    if mode == "psql":
        return _try_psql(sql)
    return False, "offline: execution skipped"


def evaluate_case(
    case: dict[str, Any],
    mode: str,
    db_available: bool,
) -> dict[str, Any]:
    case_id = case.get("id") or case.get("question", "?")
    question = case["question"]
    domain = case.get("domain")
    result: dict[str, Any] = {
        "id": case_id,
        "domain": domain,
        "question": question,
        "passed": False,
        "mode": mode,
    }

    try:
        mapped = map_question_to_sql(question, domain=domain)
    except ValueError as exc:
        result["error"] = str(exc)
        result["check"] = "mapper"
        return result

    result["sql"] = mapped.sql
    result["template_id"] = mapped.template_id

    structural_ok, structural_detail = _sql_matches_expected(mapped.sql, case)
    result["structural_ok"] = structural_ok
    result["structural_detail"] = structural_detail

    if not structural_ok:
        result["error"] = structural_detail
        result["check"] = "structural"
        return result

    if not mapped.sql.strip():
        result["error"] = "empty SQL"
        result["check"] = "structural"
        return result

    if db_available:
        exec_ok, exec_detail = execute_sql(mapped.sql, mode)
        result["executed"] = exec_ok
        result["exec_detail"] = exec_detail
        if not exec_ok:
            result["error"] = exec_detail
            result["check"] = "execute"
            return result
        result["check"] = "execute"
        result["passed"] = True
        return result

    # Offline: structural pass is enough.
    result["executed"] = False
    result["check"] = "structural_offline"
    result["passed"] = True
    return result


def run_eval(artifact_path: Optional[Path] = None) -> dict[str, Any]:
    """Run golden NL2SQL eval and write JSON artifact. Returns summary dict."""
    cases = _load_golden()
    mode, db_available = probe_db()
    results = [evaluate_case(c, mode=mode, db_available=db_available) for c in cases]

    passed = sum(1 for r in results if r.get("passed"))
    failed = len(results) - passed
    summary: dict[str, Any] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        "db_available": db_available,
        "total": len(results),
        "passed": passed,
        "failed": failed,
        "ok": failed == 0,
        "cases": results,
    }

    out = Path(artifact_path) if artifact_path else DEFAULT_ARTIFACT
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        f.write("\n")
    summary["artifact"] = str(out)
    return summary


def main(argv: Optional[list[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Run offline-first NL2SQL golden eval")
    parser.add_argument(
        "--artifact",
        type=Path,
        default=DEFAULT_ARTIFACT,
        help="Output JSON path (default: artifacts/nl2sql_eval.json)",
    )
    args = parser.parse_args(argv)
    summary = run_eval(artifact_path=args.artifact)
    status = "PASS" if summary["ok"] else "FAIL"
    print(
        f"nl2sql eval {status}: {summary['passed']}/{summary['total']} "
        f"(mode={summary['mode']}, artifact={summary['artifact']})"
    )
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
