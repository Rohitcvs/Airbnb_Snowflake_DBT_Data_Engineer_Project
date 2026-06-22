# Airbnb Data Engineering Pipeline (Snowflake + dbt)

This is an end-to-end data pipeline that takes raw Airbnb data — listings, hosts, and bookings — and turns it into clean, analytics-ready tables in Snowflake. The transformations are all handled with dbt, organized into a Bronze → Silver → Gold medallion structure, with incremental loading and SCD Type 2 snapshots to track how records change over time.

I built it mainly to get hands-on with dbt's modeling patterns (incremental models, snapshots, macros, and Jinja) against a real warehouse rather than a toy setup.

## How I set it up

The flow is straightforward: source CSVs land in Snowflake's staging schema, and dbt builds everything from there.

```
Source CSVs → Snowflake (staging) → Bronze → Silver → Gold
                                       raw     cleaned   analytics-ready
```

The CSVs originate from local files that get loaded into staging — in a production version these would sit in S3 and load through a Snowflake stage, but here they're loaded directly to keep the setup simple.

## What I used

- **Snowflake** as the warehouse
- **dbt** for all transformations, tests, and documentation
- **Python 3.12** for the surrounding tooling and orchestration script
- **Git** for version control
- **sqlfmt** to keep the SQL consistently formatted

The interesting dbt features in here are incremental models, snapshots for slowly changing dimensions, a few custom macros, and Jinja-driven SQL generation for the wide fact table.

## How I modeled the data

The whole thing is laid out as a medallion architecture, so each layer has a clear job.

**Bronze** is the raw landing zone. The data comes straight out of staging with almost no changes — just `bronze_bookings`, `bronze_hosts`, and `bronze_listings`. The point is to have an untouched copy to rebuild from if anything downstream goes wrong.

**Silver** is where the cleaning happens. Records get validated and standardized: `silver_bookings` holds the cleaned transactions, `silver_hosts` adds some quality metrics to host profiles, and `silver_listings` standardizes the listing fields and buckets prices into categories.

**Gold** is what analysts actually query. `obt` is a denormalized "one big table" that joins bookings, listings, and hosts together, and `fact` is the fact table for dimensional modeling. There are also a few ephemeral models that exist only as intermediate steps and never get written to the warehouse.

On top of those, the snapshots track history. `dim_bookings`, `dim_hosts`, and `dim_listings` are SCD Type 2, so when a record changes, the old version is preserved with valid-from/valid-to dates instead of being overwritten. That makes point-in-time analysis possible.

## How the repo is laid out

```
AWS_DBT_Snowflake/
├── README.md
├── pyproject.toml                       # Python dependencies
├── main.py                              # Entry-point script
│
├── SourceData/                          # Raw CSV files
│   ├── bookings.csv
│   ├── hosts.csv
│   └── listings.csv
│
├── DDL/                                 # Staging table definitions
│   ├── ddl.sql
│   └── resources.sql
│
└── aws_dbt_snowflake_project/           # The dbt project itself
    ├── dbt_project.yml
    ├── ExampleProfiles.yml              # Template for the connection profile
    │
    ├── models/
    │   ├── sources/sources.yml          # Source definitions
    │   ├── bronze/                      # Raw layer
    │   ├── silver/                      # Cleaned layer
    │   └── gold/                        # Analytics layer (+ ephemeral models)
    │
    ├── macros/                          # Reusable SQL
    │   ├── generate_schema_name.sql     # Custom schema naming
    │   ├── multiply.sql
    │   ├── tag.sql                      # Price categorization
    │   └── trimmer.sql                  # String cleanup
    │
    ├── analyses/                        # Ad-hoc / scratch queries
    ├── snapshots/                       # SCD Type 2 configs
    ├── tests/                           # Data quality tests
    └── seeds/                           # Static reference data
```

## How to run it

You'll need a Snowflake account and Python 3.12 or newer. Everything else installs from the project.

Clone it and set up an environment:

```bash
git clone <repository-url>
cd AWS_DBT_Snowflake

python -m venv .venv
source .venv/bin/activate        # macOS / Linux
# .venv\Scripts\Activate.ps1     # Windows PowerShell

pip install -e .
```

The core dependencies are `dbt-core` (>=1.11.2), `dbt-snowflake` (>=1.11.0), and `sqlfmt`.

Next, point dbt at your Snowflake account. Copy the template in `ExampleProfiles.yml` to `~/.dbt/profiles.yml` and fill in your own values:

```yaml
aws_dbt_snowflake_project:
  outputs:
    dev:
      account: <your-account-identifier>
      database: AIRBNB
      password: <your-password>
      role: ACCOUNTADMIN
      schema: dbt_schema
      threads: 4
      type: snowflake
      user: <your-username>
      warehouse: COMPUTE_WH
  target: dev
```

Then create the staging tables by running `DDL/ddl.sql` in Snowflake, and load the three CSVs from `SourceData/` into the staging schema (`bookings.csv` → `AIRBNB.STAGING.BOOKINGS`, and the same for hosts and listings).

## Running it day to day

Once the connection works (`dbt debug` will tell you), the usual workflow is:

```bash
cd aws_dbt_snowflake_project

dbt debug          # confirm the connection
dbt deps           # install any packages
dbt run            # build all models
dbt test           # run data quality tests
dbt snapshot       # update the SCD Type 2 dimensions
dbt build          # run models, tests, and snapshots together
```

If you only want one layer, you can target it directly — `dbt run --select silver.*` builds just the silver models, and the same pattern works for bronze and gold.

To browse the lineage graph and docs locally:

```bash
dbt docs generate
dbt docs serve
```

## A few things worth pointing out

**Incremental loading.** The bronze and silver models are incremental, so a normal run only processes new or changed rows instead of rebuilding everything:

```sql
{{ config(materialized='incremental') }}

{% if is_incremental() %}
  where created_at > (select coalesce(max(created_at), '1900-01-01') from {{ this }})
{% endif %}
```

**The `tag()` macro.** This is a small piece of reusable business logic that buckets a nightly price into low/medium/high so I'm not repeating the same `case` expression everywhere:

```sql
{{ tag('cast(price_per_night as int)') }} as price_per_night_tag
```

**Jinja-generated joins.** The one-big-table model builds its joins from a config list with a Jinja loop, which keeps it readable when the number of joined sources grows instead of being a wall of hand-written SQL.

**Schema separation by layer.** Thanks to the `generate_schema_name` macro, models route to their own schemas automatically — bronze models land in `AIRBNB.BRONZE`, silver in `AIRBNB.SILVER`, and gold in `AIRBNB.GOLD`.

## How I handle testing and lineage

Data quality is handled with a mix of dbt's built-in tests (unique keys, not-null, referential integrity) and a few custom checks for business rules, plus source validation on the way in. Because everything is modeled in dbt, the lineage comes for free — you can see exactly what each model depends on upstream and what it feeds into downstream, all the way from source to the gold tables.

## How I handle credentials

Keep your real `profiles.yml` out of version control — it has your Snowflake password in it. The repo only ships the `ExampleProfiles.yml` template with placeholders. Better still, pull secrets from environment variables (dbt supports `{{ env_var('SNOWFLAKE_PASSWORD') }}`) so nothing sensitive ever sits in a file, and lean on Snowflake's role-based access control rather than running everything as `ACCOUNTADMIN` in a real deployment.

## What I'll add next

- I'll build a data quality / freshness dashboard
- I'll set up a CI/CD pipeline so models get tested on every push
- I'll add more business-level metrics in the gold layer
- I'll connect a BI tool on top (Tableau or Power BI)
- I'll add PII masking and basic alerting/monitoring

## How to troubleshoot it

If `dbt run` can't connect, it's almost always the profile — double-check the account identifier and credentials in `profiles.yml`, and make sure the warehouse is actually running. Compilation errors usually trace back to a Jinja typo or a missing dependency, and `dbt debug` is the fastest way to find them. If an incremental model looks wrong, `dbt run --full-refresh` rebuilds it from scratch.

---

Built as a portfolio project to demonstrate an end-to-end dbt and Snowflake workflow.
