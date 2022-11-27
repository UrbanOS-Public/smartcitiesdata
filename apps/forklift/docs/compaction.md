# Compaction

Compaction is a process that consolidates the data stored in Minio.
This process greatly improves read performance in user queries through
Hive and Trino.

## Data Flow

The following is a detailed technical description of how data is moved across
Trino tables, to become "compacted" and available to the rest of the system.
(Discovery API / UI)

Ideally you do not need to understand these internal systems to utilize Forklift,
but the information is here for developers making changes to the system.

### How it will work

1. A group of ingested data payloads from Reaper are sent to Forklift
1. Forklift creates a `#{system_name}` (aka main) table with the schema that
   aligns with the data payload, plus adds `_extraction_start_time`, `_ingestion_id`
   and `os_partition`, in that order. This table is partitioned by
   `_ingestion_id` and `os_partition`.
1. Forklift adds the `_ingestion_id` and `_extraction_start_time` attribute to each
   data payload as it comes in.
1. Forklift stores this new data in a table titled: `#{system_name}\__json`
   (At this time it's not available to Discovery UI / API. Only data in the
   `#{system_name}` table is ever available.) Later we'll need to delete
   specific extractions from this table. To allow this, the `json` table is
   partitioned by `_ingestion_id` and `_extraction_start_time`. Only entire
   partitions can be deleted at a time, no partial selections of data.
   Partitioning this way allows for deleting an entire extraction from the
   json table.
1. Once the extract is complete, "compaction" starts with
   `DataMigration.compact`. The goal of compaction is for any data in the
   `__json` table that matches the recently completed `_ingestion_id` and
   `_extraction_start_time` to be moved into the main table, and made accessible to
   the rest of UrbanOS through Discovery API.

   1. `DataMigration.compact` replaces the `#{system_name}` table with a copy
      that's partitioned by `os_partition` (`refit_to_partitioned`). This ends
      up happening only once per dataset.
   1. If "OVERWRITE MODE" is enabled, messages that match the `_ingestion_id`
      are deleted from the main table.
   1. `insert_partitioned_data` moves everything that matches `_ingestion_id`
      and `_extraction_start_time` from the `__json` table to the main table.
   1. The entires that were copied (matching `_ingestion_id` and
      `_extraction_start_time`) are removed from the json_table.

1. On a nightly cadence ([00:45](https://github.com/UrbanOS-Public/smartcitiesdata/blob/e044d548461cb6a53b915e082bf613387c491005/apps/forklift/runtime.exs#L137)), another compaction process called
   `PartitionedCompaction.compact` occurs. The goal of `ParitionedCompaction`
   is to further reduce the number of files stored in hive.
   1. Create an intermediate "compact" table which is just a copy of the main
      table schema. This intermediate table is not partitioned but that doesn't
      matter
   1. Copy all data that matches MMYYYY (`os_partition`) from "main" to "compact"
   1. Delete data from "main" that matches MMYYYY
   1. Insert MMYYYY data from "compact" back into "main".
   1. Clean up: Delete the intermediate "compact" table

## Notes:

Partitions:
The partition column is not stored with this data; it is a virtual column that is deciphered from the partition directory your data is present in. [source](https://stackoverflow.com/a/10307756)

Ex: The json table partitioned by `_ingestion_id` and `_extraction_start_time` for
will have it's files stored in:
`hive/_ingestion_id=12345/_extraction_start_time=1661952636/payload.{ext}`

Without partitions, hive loads every file into memory to parse it for matching
results. Partitions limit the amount of files required to be loaded into memory,
making queries significantly more efficient in some cases.

---

What is OVERWRITE_MODE?

This mode only keeps the latest data per ingestion in the main table at all times.
This allows UrbanOS to use significantly less storage if they only care about
having the latest data accessible.

---

Why is it helpful to have the `#system_name` table (aka main table or orc table)
partitioned by `os_partition`? It only optimizes queries when
people write queries that specify MMYYYY right?

- True, that's the only query optimization but:
- Wanted to reduce the amount of files behind hive to just one file per MMYYYY
  per ingestion.
- This is where the word "compact" comes from: compact all files
  (~file for every extraction), into one file per ingestion_id per MMYYYY.
- A side effect is that queries that utilize the partition field or ingestion_id
  are highly speed up.

## Improvements:

- `os_partition` should be renamed `_os_partition` so that it's clear the value
  came from UrbanOS attaching metadata. Would align with `_extraction_start_time` and
  `_ingestion_id`.
