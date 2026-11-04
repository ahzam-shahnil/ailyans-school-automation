#!/usr/bin/env python3
"""Bulk-seed Supabase PostgreSQL from the live Ailyans SQLite database.

Uses PostgREST's native table endpoint with merge-duplicates upserts:

    POST /rest/v1/{Table}?on_conflict={pk_columns}
    Prefer: resolution=merge-duplicates,return=representation

Every row carries an explicit updated_at (UTC ISO8601) because DEFAULT now()
does not fire for the update half of an upsert. Success is verified from the
returned JSON rows and the Content-Range header, never from HTTP status alone.

Stdlib only. Credentials are read from the environment first, then from the
app's .env file. Credentials are never printed.
"""

import json
import os
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = APP_ROOT / ".env"
SQLITE_PATH = Path.home() / "Documents" / "Ailyans" / "school_database.db"

BATCH_SIZE = 500
MAX_ATTEMPTS = 4

# (table, comma-separated on_conflict columns), parents first.
TABLE_SPECS = [
    ("Stu_Reg", "Stu_RegID"),
    ("Teachers", "TeacherID"),
    ("Books", "BookID"),
    ("ExamInfo", "ExTermID,SessionYR"),
    ("app_config", "config_key"),
    ("Student_Class", "Stu_RegID,ClassID,SessionYr"),
    ("Sibling_Links", "LinkID"),
    ("VoucharMas", "VoucherMasID"),
    ("TSalMas", "TeacherID,SalMonth"),
    ("ExamMas", "ExamInfoID,Stu_RegID"),
    ("SchLeaving", "StuRegID"),
    # F-3c-2: VoucherMasID added to Supabase DDL. The seeder reads the column
    # via SELECT * and POSTs it. No code change here.
    ("StuAdv", "StuAdvID"),
    ("VoucharDet", "VoucharDetID,VoucharMasID,feeParameterID"),
    ("TSalDet", "TSalMasID,Detail"),
    ("AttMas", "ClassID,ClassSecID,AttDate"),
    ("ExamDet", "ExamMasID,SubjID"),
    ("FeeTransaction", "FeeTransID"),
    ("AttDet", "AttMasID,Stu_RegID"),
    ("TAtt", "TeacherID,AttDate"),
]

REQUIRED_KEYS = ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")


def parse_env_file(path):
    """Parse KEY=VALUE lines, ignoring comments and stripping quotes."""
    values = {}
    if not path.exists():
        return values
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                value = value[1:-1]
            if key:
                values[key] = value
    return values


def load_config():
    """Environment wins; the app .env fills in anything missing."""
    file_values = parse_env_file(ENV_PATH)
    return {
        key: os.environ.get(key) or file_values.get(key, "")
        for key in REQUIRED_KEYS
    }


def parse_content_range(value):
    """Return the affected-row count from a PostgREST Content-Range header."""
    if not value:
        return None
    match = re.match(r"^(?:(\d+)-(\d+)|\*)/(\d+|\*)$", value.strip())
    if not match:
        return None
    start, end, total = match.groups()
    if start is not None and end is not None:
        return int(end) - int(start) + 1
    if total != "*":
        return int(total)
    return None


def parse_upsert_response(response, table, batch_size):
    """Return the number of rows the server confirms were upserted."""
    raw = response.read()
    content_range = response.headers.get("Content-Range")
    range_count = parse_content_range(content_range)

    parsed = None
    if raw:
        try:
            parsed = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            parsed = None

    body_count = len(parsed) if isinstance(parsed, list) else None

    if body_count is not None and range_count is not None and body_count != range_count:
        print(
            f"  [WARN] table={table} body_count={body_count} "
            f"Content-Range={content_range}",
            file=sys.stderr,
            flush=True,
        )
    if content_range is None:
        print(
            f"  [WARN] table={table} missing Content-Range; "
            f"body_count={body_count}",
            file=sys.stderr,
            flush=True,
        )

    if body_count is not None:
        returned = body_count
    elif range_count is not None:
        returned = range_count
        print(
            f"  [WARN] table={table} body was not a JSON array; "
            f"using Content-Range={content_range}",
            file=sys.stderr,
            flush=True,
        )
    else:
        returned = 0
        print(
            f"  [WARN] table={table} no JSON array body and no parsable "
            f"Content-Range; counted 0",
            file=sys.stderr,
            flush=True,
        )

    if returned != batch_size:
        print(
            f"  [WARN] table={table} expected={batch_size} "
            f"returned={returned} Content-Range={content_range}",
            file=sys.stderr,
            flush=True,
        )

    return returned


def post_batch(base_url, service_key, table, on_conflict, batch):
    """POST one batch. Returns (ok, returned, error_text, retryable)."""
    url = f"{base_url}/rest/v1/{table}?on_conflict={on_conflict}"
    body = json.dumps(batch, ensure_ascii=False).encode("utf-8")
    last_error = None

    for attempt in range(MAX_ATTEMPTS):
        request = urllib.request.Request(
            url,
            data=body,
            headers={
                "apikey": service_key,
                "Authorization": f"Bearer {service_key}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates,return=representation",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                status = getattr(response, "status", 200)
                if status in (200, 201):
                    returned = parse_upsert_response(response, table, len(batch))
                    return True, returned, None, False
                detail = response.read().decode("utf-8", errors="replace")
                return (
                    False,
                    0,
                    f"unexpected HTTP {status}: {detail}",
                    False,
                )
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            code = error.code
            if 400 <= code < 500:
                return False, 0, f"HTTP {code}: {detail}", False
            if 500 <= code < 600:
                last_error = f"HTTP {code}: {detail}"
            else:
                return False, 0, f"HTTP {code}: {detail}", False
        except Exception as error:  # network, DNS, timeout, TLS
            last_error = f"{type(error).__name__}: {error}"

        if attempt < MAX_ATTEMPTS - 1:
            delay = 2 ** attempt
            print(
                f"  [retry] table={table} attempt={attempt + 1}/{MAX_ATTEMPTS} "
                f"sleep={delay}s error={last_error}",
                file=sys.stderr,
                flush=True,
            )
            time.sleep(delay)

    return False, 0, last_error, True


def main():
    config = load_config()
    missing = [key for key in REQUIRED_KEYS if not config[key]]
    if missing:
        print(f"ERROR: missing credentials: {', '.join(missing)}", file=sys.stderr)
        print(f"Set them in the environment or in {ENV_PATH}", file=sys.stderr)
        return 1

    base_url = config["SUPABASE_URL"].rstrip("/")
    service_key = config["SUPABASE_SERVICE_ROLE_KEY"]

    if not SQLITE_PATH.exists():
        print(f"ERROR: SQLite database not found: {SQLITE_PATH}", file=sys.stderr)
        return 1

    connection = sqlite3.connect(f"file:{SQLITE_PATH}?mode=ro", uri=True)
    cursor = connection.cursor()

    summary = []
    total_rows = total_ok = total_fail = 0

    try:
        for table, on_conflict in TABLE_SPECS:
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                (table,),
            )
            if cursor.fetchone() is None:
                print(f"ERROR: missing SQLite table: {table}", file=sys.stderr)
                return 1

            cursor.execute(f'SELECT * FROM "{table}"')
            columns = [description[0] for description in cursor.description]
            started = time.monotonic()
            rows = ok = fail = 0
            batch_number = 0

            while True:
                batch_rows = cursor.fetchmany(BATCH_SIZE)
                if not batch_rows:
                    break
                batch_number += 1
                rows += len(batch_rows)

                batch = []
                for row in batch_rows:
                    row_dict = dict(zip(columns, row))
                    row_dict["updated_at"] = datetime.now(
                        timezone.utc
                    ).isoformat()
                    batch.append(row_dict)

                success, returned, error, retryable = post_batch(
                    base_url, service_key, table, on_conflict, batch
                )
                if success:
                    uploaded = min(returned, len(batch))
                    ok += uploaded
                    fail += len(batch) - uploaded
                else:
                    fail += len(batch)
                    if retryable:
                        print(
                            f"  [retry exhausted] table={table} "
                            f"batch={batch_number} rows={len(batch)} {error}",
                            file=sys.stderr,
                            flush=True,
                        )
                    else:
                        print(
                            f"  [FAIL] table={table} batch={batch_number} "
                            f"rows={len(batch)} {error}",
                            file=sys.stderr,
                            flush=True,
                        )

            elapsed = time.monotonic() - started
            print(
                f"table={table} rows={rows} ok={ok} fail={fail} "
                f"elapsed={elapsed:.2f}",
                flush=True,
            )
            summary.append((table, rows, ok, fail))
            total_rows += rows
            total_ok += ok
            total_fail += fail
    finally:
        cursor.close()
        connection.close()

    print()
    print(f"{'Table':<24} {'SQLite':>8} {'Uploaded':>10} {'Failed':>8}")
    print("-" * 54)
    for table, rows, ok, fail in summary:
        print(f"{table:<24} {rows:>8} {ok:>10} {fail:>8}")
    print("-" * 54)
    print(f"{'TOTAL':<24} {total_rows:>8} {total_ok:>10} {total_fail:>8}")

    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
