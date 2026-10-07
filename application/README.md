# Ingest application (Python)

This package is the **Cloud Run Job** container logic: a single CLI entrypoint runs **load descriptor → extract from Oracle ERP → transform hook → JSON Schema validation → load to PostgreSQL DWH with dlt**.

It is installed as an editable package (see **`pyproject.toml`**) and started with:

```bash
python -m src.main
```

The descriptor path defaults to **`DESCRIPTOR_PATH`** or **`/app/descriptor/data-product-descriptor.json`**. The descriptor file is expected to be valid DPDS-shaped JSON with **datastoreapi** input and output ports; parsing and validation of that contract live in **`src/descriptor_loader.py`**.

## Execution flow (`src/main.py`)

1. **`load_descriptor()`** — Reads the JSON file, builds one **`InputIngestConfig`** per **`interfaceComponents.inputPorts[]`** entry and one **`OutputIngestConfig`** from the first output port.
2. **`build_validator()`** — Turns the output port’s **`tables[0].definition.properties`** into a **Draft 2020-12** JSON Schema and constructs a **`jsonschema`** validator.
3. **`extract_rows()`** (per input config) — Opens a **SQLAlchemy** engine from the Oracle secret, runs a bounded query for the configured schema and table, adds the **row discriminator** column, and supports an optional **incremental cursor** with optional **`CURSOR_STATE_PATH`** persistence.
4. **`transform_hook.transform_rows()`** — Product-specific mapping from raw rows to the output row shape. Not implemented in the blueprint stub unless **`TRANSFORM_HOOK_IDENTITY=1`**.
5. **`validate_rows()`** — Fail-fast validation of each transformed row against the output schema; **`SystemExit(1)`** on first validation error.
6. **`load_to_postgres()`** — Configures **dlt** with the PostgreSQL destination, materializes rows, and runs the pipeline (**`write_disposition="replace"`** on the resource in code as shipped).

## Modules

| Module | Responsibility |
| --- | --- |
| **`src/descriptor_loader.py`** | Parse DPDS JSON; **`InputIngestConfig`** / **`OutputIngestConfig`**; map **datastoreapi** column **`properties`** to a JSON Schema object via **`datastore_properties_to_json_schema`**. |
| **`src/extract.py`** | Oracle URL construction from URI or JSON secret payload; identifier validation; cursor state load/save; streaming iterator of row dicts. |
| **`src/validate_output.py`** | **`Draft202012Validator`** wiring and row-by-row validation. |
| **`src/load_dlt.py`** | Resolve PostgreSQL DWH connection string, build **dlt** pipeline and **`@dlt.resource`**, run **`pipeline.run`**. |
| **`transform_hook.py`** (package root) | **`transform_rows(rows, *, input_configs, output_config)`** — you implement the iterable of dicts matching **`output_config.physical_schema`**. This file is the product-side extension point; keep mapping here so blueprint version updates merge cleanly. **`application/src/`** is owned by the blueprint (`protectedResources`). |

## `transform_hook.transform_rows`

Signature:

```python
def transform_rows(
    rows: Iterable[dict],
    *,
    input_configs: tuple[InputIngestConfig, ...],
    output_config: OutputIngestConfig,
) -> Iterable[dict]:
    ...
```

- **`input_configs`**: one entry per input port (schema name, source table, discriminator column name, optional cursor field from env).
- **`output_config`**: schema id, table id, **`physical_schema`** (JSON Schema dict).

Return an iterable of **plain dicts** whose keys and types satisfy the validator built from **`output_config.physical_schema`**.

## Environment variables read by this code

| Variable | Used in |
| --- | --- |
| **`DESCRIPTOR_PATH`** | **`descriptor_loader.load_descriptor`** (default path if unset). |
| **`SOURCES__ORACLE__CREDENTIALS`** | **`extract`** — file path or inline connection material. |
| **`DESTINATION__POSTGRES__CREDENTIALS`** | **`load_dlt`** — file path or inline connection material. |
| **`INGEST_CURSOR_FIELD`**, **`INGEST_ROW_DISCRIMINATOR_COLUMN`** | **`descriptor_loader`** / **`extract`**. |
| **`CURSOR_STATE_PATH`** | **`extract`** — optional watermark file location. |
| **`TRANSFORM_HOOK_IDENTITY`** | **`transform_hook`** — set to **`1`** only for identity-through smoke tests. |

For local runs without Terraform, set these variables yourself consistently with your descriptor and target PostgreSQL DWH table.
