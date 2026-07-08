# dlt pipeline: load validated rows to the PostgreSQL DWH table declared in the output port contract.
# Purpose: isolate destination I/O and credentials env wiring from extract/transform logic.
from __future__ import annotations

import json
import logging
import os
from collections.abc import Iterable
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus

import dlt
from dlt.destinations import postgres

from .descriptor_loader import OutputIngestConfig

logger = logging.getLogger(__name__)


def _resolve_secret_value(env_name: str) -> str:
    raw = os.environ.get(env_name)
    if not raw:
        raise RuntimeError(f"Missing environment variable {env_name}")
    path = Path(raw)
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return raw.strip()


def _build_postgres_connection_string(secret_payload: str) -> str:
    if secret_payload.startswith("postgresql://") or secret_payload.startswith("postgres://"):
        return secret_payload
    if secret_payload.startswith("postgresql+"):
        return secret_payload
    data = json.loads(secret_payload)
    host = data["host"]
    port = int(data.get("port", 5432))
    user = data["user"]
    password = data["password"]
    dbname = data["database"]
    return (
        "postgresql+psycopg2://"
        f"{quote_plus(user)}:{quote_plus(password)}@{host}:{port}/{quote_plus(dbname)}"
    )


def load_to_postgres(rows: Iterable[dict[str, Any]], output_cfg: OutputIngestConfig) -> None:
    secret = _resolve_secret_value(output_cfg.credentials_secret_env)
    connection_string = _build_postgres_connection_string(secret)

    destination = postgres(credentials=connection_string)

    pipeline = dlt.pipeline(
        pipeline_name=f"{output_cfg.schema_id}_{output_cfg.table_id}_ingest",
        destination=destination,
        dataset_name=output_cfg.schema_id,
    )

    row_list = list(rows)

    @dlt.resource(
        name=output_cfg.table_id,
        write_disposition="replace",
    )
    def contract_table() -> Iterable[dict[str, Any]]:
        yield from row_list

    load_info = pipeline.run(contract_table())
    logger.info("dlt load completed: %s", load_info)
