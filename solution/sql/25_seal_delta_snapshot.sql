-- Seal an immutable correction-ledger cut before building minute generations.
-- The caller derives/passes source_delta_snapshot from the printed candidate or
-- allocates it once, then retries with the same token and cutoff.

SELECT throwIf(
    count() > 0,
    'source_delta_snapshot already exists; never reuse a snapshot ID'
)
FROM sonyliv.delta_snapshots
WHERE source_delta_snapshot = {source_delta_snapshot:UInt128};

SELECT throwIf(
    count() != uniqExact(adjustment_batch_id),
    'duplicate adjustment batch IDs in the requested ledger cut'
)
FROM sonyliv.published_adjustment_batches
WHERE policy_version = {policy_version:String}
  AND pipeline_run_id = {pipeline_run_id:UUID}
  AND published_at <= toDateTime64({snapshot_cutoff:String}, 3, 'UTC');

INSERT INTO sonyliv.delta_snapshots
WITH ledger AS
(
    SELECT
        adjustment_batch_id,
        adjustment_block_hash,
        adjustment_rows AS batch_adjustment_rows
    FROM sonyliv.published_adjustment_batches
    WHERE policy_version = {policy_version:String}
      AND pipeline_run_id = {pipeline_run_id:UUID}
      AND published_at <= toDateTime64({snapshot_cutoff:String}, 3, 'UTC')
), summarized AS
(
    SELECT
        count() AS adjustment_batches,
        sum(batch_adjustment_rows) AS total_adjustment_rows,
        hex(
            SHA256(
                arrayStringConcat(
                    arraySort(
                        groupArray(
                            concat(
                                toString(adjustment_batch_id),
                                ':',
                                toString(adjustment_block_hash),
                                ':',
                                toString(batch_adjustment_rows)
                            )
                        )
                    ),
                    '\n'
                )
            )
        ) AS adjustment_ledger_hash
    FROM ledger
)
SELECT
    {source_delta_snapshot:UInt128},
    {policy_version:String},
    {pipeline_run_id:UUID},
    toDateTime64({snapshot_cutoff:String}, 3, 'UTC'),
    adjustment_batches,
    total_adjustment_rows,
    adjustment_ledger_hash,
    now64(3)
FROM summarized
SETTINGS insert_deduplication_token = {delta_snapshot_dedup_token:String};

SELECT
    source_delta_snapshot,
    policy_version,
    pipeline_run_id,
    cutoff,
    adjustment_batches,
    adjustment_rows,
    adjustment_ledger_hash
FROM sonyliv.delta_snapshots
WHERE source_delta_snapshot = {source_delta_snapshot:UInt128};
