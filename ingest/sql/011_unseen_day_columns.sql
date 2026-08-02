-- =====================================================================
-- 011_unseen_day_columns.sql — carry video_resolution through the MV
-- =====================================================================
--
-- A CONVERGENCE statement, applied by `make schema` in file order after 003 --
-- the same role as the MODIFY SETTING ALTERs in 002 and 003. On a fresh database
-- it is a harmless no-op restatement of the MV 003 just created; on a deployed
-- one it is the only thing that updates the MV.
--
-- WHY IT IS SEPARATE. `CREATE MATERIALIZED VIEW IF NOT EXISTS` is a no-op
-- against an existing MV, so 003's updated SELECT does NOT reach a deployed
-- database. Only ALTER ... MODIFY QUERY does. The ADD COLUMN statements in 002
-- and 003 are additive and idempotent and can run any time; this one changes
-- behaviour, so it is deliberate and separate.
--
-- WHY NOT DROP AND RECREATE. An MV holds no data, so dropping it looks free. It
-- is not: rows inserted into events_raw between the DROP and the CREATE are
-- never propagated to events_clean, silently, and no count will ever reveal
-- which ones. MODIFY QUERY swaps the definition without a gap.
--
-- GENERATED from 003_events_clean.sql's MV body by
-- `make unseen-mv` — do not hand-edit. Two copies of an 80-line SELECT drift;
-- a generated one cannot. Regenerate after any change to that MV.
--
-- Safe to re-run: MODIFY QUERY is idempotent for an identical body.
-- =====================================================================

ALTER TABLE {{db}}.events_raw_to_clean_mv
MODIFY QUERY
SELECT
    session_key,
    event_timestamp     AS event_ts,
    event_type,
    event,

    video_session_id,
    user_key,
    user_id,
    content_id,

    session_start_epoch AS session_start_ts,

    platform,
    app_version,
    country,

    -- Language fields are case-inconsistent by event type. Without this, every
    -- GROUP BY double-counts OFF/off and UNK/unk. 'off' is preserved as a
    -- distinct value: explicitly-disabled subtitles are not the same fact as
    -- unknown subtitles.
    if(lowerUTF8(splitByChar('-', trimBoth(audio_language))[1]) IN ('', 'unk', 'und', 'null', 'unknown'),
       'unknown',
       lowerUTF8(splitByChar('-', trimBoth(audio_language))[1]))       AS audio_language,

    if(lowerUTF8(splitByChar('-', trimBoth(subtitle_language))[1]) IN ('', 'unk', 'und', 'null', 'unknown'),
       'unknown',
       lowerUTF8(splitByChar('-', trimBoth(subtitle_language))[1]))    AS subtitle_language,

    if(empty(trimBoth(player_version)), 'unknown', trimBoth(player_version)) AS player_version,

    -- Trimmed but NOT defaulted to 'unknown' -- see the column comment above.
    trimBoth(video_resolution)                                       AS video_resolution,

    multiIf(
        event_type = 'VideoSessionStart', 'session_start',
        event_type = 'VideoSessionEnd',   'session_end',
        event_type = 'VideoPlay',         'play',
        event_type = 'AppBackgrounded',   'background',
        event_type = 'AppForegrounded',   'foreground',
        event_type = 'VideoError',        'error',
        -- Only the bare 'pause' / 'resume' are play-state transitions.
        --
        -- 'adpause'/'adresume' and 'speed-pause'/'speed-resume' are deliberately
        -- excluded and fall through to 'liveness'. Neither is the viewer
        -- stopping watching:
        --
        --   * an ad break is the player pausing itself — the session is still
        --     open, on screen and being watched;
        --   * a speed-pause/resume pair brackets a playback-rate change, not an
        --     absence.
        --
        -- Classing either as 'pause' would drop the session out of the
        -- concurrency count for the duration of an ad break or a speed change.
        -- For ads that is worst precisely in the hot hours, where ad load is
        -- densest — the metric would sag exactly where it matters most.
        -- 'liveness' is the honest classification: proof the session is alive,
        -- with no play-state transition to apply.
        --
        -- Measured in the supplied extract: speed-pause 380, speed-resume 380,
        -- AdPause 45, AdResume 27 — 832 rows reclassified out of pause/resume.
        -- Small in this extract, but both rates are functions of ad load and
        -- player features rather than of this dataset, so they are not safe to
        -- treat as negligible on the unseen day.
        --
        -- This is a play-state decision only. They are NOT flagged as
        -- is_periodic_ping either — that flag means the {network-activity,
        -- buffer-health, video-resize} trio specifically, and neither an ad nor
        -- a speed change is periodic.
        lowerUTF8(event) = 'pause',  'pause',
        lowerUTF8(event) = 'resume', 'resume',
        'liveness')                                                  AS signal,

    event IN ('network-activity', 'buffer-health', 'video-resize')   AS is_periodic_ping,

    bitShiftLeft(toUInt64(toUnixTimestamp64Milli(_ingested_at)), 20)
        + toUInt64(_batch_row_seq)                                   AS row_version,

    _ingest_batch_id                                                 AS ingest_batch_id
FROM {{db}}.events_raw;
