-- Select a deterministic batch of unapplied dirty operations. This is an
-- append-only queue: no run-local max(version) can hide a later ingestion batch.

INSERT INTO sonyliv.compaction_worksets
SELECT
    {adjustment_batch_id:UUID} AS adjustment_batch_id,
    d.video_session_id,
    arraySort(groupUniqArray(d.dirty_operation_id)) AS dirty_operation_ids,
    now64(3) AS selected_at
FROM sonyliv.dirty_session_events AS d
LEFT ANTI JOIN sonyliv.applied_dirty_operations AS a
    ON d.dirty_operation_id = a.dirty_operation_id
LEFT ANTI JOIN sonyliv.compaction_worksets AS existing
    ON existing.adjustment_batch_id = {adjustment_batch_id:UUID}
   AND existing.video_session_id = d.video_session_id
GROUP BY d.video_session_id
ORDER BY min(d.last_ingested_at), d.video_session_id
LIMIT {max_touched_sessions:UInt64}
SETTINGS insert_deduplication_token = {workset_dedup_token:String};

SELECT
    count() AS touched_sessions,
    arraySum(groupArray(length(dirty_operation_ids))) AS dirty_operations
FROM sonyliv.compaction_worksets
WHERE adjustment_batch_id = {adjustment_batch_id:UUID};

