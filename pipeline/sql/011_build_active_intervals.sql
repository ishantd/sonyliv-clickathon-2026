-- ============================================================================
-- Stage 01: build active viewing intervals from events_clean.
--
-- One file, two modes. full_scan=1 rebuilds every session; full_scan=0 rebuilds
-- only the sessions queued in dirty_sessions past a watermark. Same 13-CTE
-- state machine either way -- that is the point. The full-scan run is the
-- oracle that validates the incremental run, and if they were separate code a
-- divergence between them would be invisible to the very check designed to
-- catch it.
--
-- Run with:
--   clickhouse-client --multiquery \
--     --param_policy_version=sonyliv-active-v1 \
--     --param_heartbeat_timeout_ms=120000 \
--     --param_full_scan=1 \
--     --param_since_ingested_at='' \
--     --param_evaluation_as_of='' \
--     --param_allow_truncation=0 \
--     --param_allow_boundary_sessions=0 \
--     --param_state_revision=1 \
--     --param_insert_token='stage01:sonyliv-active-v1:full:rev1' \
--     < pipeline/sql/011_build_active_intervals.sql
--
-- evaluation_as_of='' derives the cutoff as max(event_ts) + heartbeat_timeout.
-- Pass a literal only for a deliberate point-in-time replay.
--
-- Do NOT attach this to events_clean as an incremental materialized view. An
-- incremental MV sees only its own inserted block, and this derives ordered
-- state across a session's entire history.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Guard 1: evaluation_as_of must parse, and must not silently truncate.
--
-- Too high is harmless -- least() clamps every interval to
-- last_eligible_signal + timeout regardless. Too low drops events with no
-- error and no row-count difference to notice: the concurrency curve just ends
-- early. One-sided silent failure, which is the worst shape.
-- ----------------------------------------------------------------------------

-- NOTE on the parsing here: do NOT reach for
--   ifNull(toDateTime64OrNull(param, 3, 'UTC'), fallback)
-- toDateTime64OrNull('') returns the EPOCH, not NULL, so ifNull never reaches the
-- fallback and evaluation_as_of silently becomes 1970-01-01 -- which then filters
-- out every row and the build returns zero intervals. Measured, not theoretical.
-- An explicit empty-string test is the only safe form.

SELECT throwIf(
    {evaluation_as_of:String} != ''
        AND toDateTime64OrZero({evaluation_as_of:String}, 3, 'UTC') = toDateTime64(0, 3, 'UTC'),
    'evaluation_as_of does not parse as a UTC timestamp. Pass an empty string to derive it from max(event_ts).'
);

SELECT throwIf(
    {allow_truncation:UInt8} = 0
        AND {evaluation_as_of:String} != ''
        AND toDateTime64OrZero({evaluation_as_of:String}, 3, 'UTC')
            < (SELECT max(event_ts) FROM sonyliv.events_clean),
    'evaluation_as_of is below max(event_ts) and would silently drop events. Pass allow_truncation=1 if this point-in-time replay is deliberate.'
);


-- ----------------------------------------------------------------------------
-- Guard 0: the content dictionary must actually be loaded.
--
-- Dictionaries are an in-memory cache loaded independently per replica, lazily,
-- on first use. Both replicas can report status = 'LOADED' while one holds zero
-- rows -- observed on this service:
--
--   c-...-7v70m4s-0   LOADED   element_count = 33464
--   c-...-xtd9zjc-0   LOADED   element_count = 0
--
-- On the cold replica dictGetOrDefault returns the fallback for EVERY lookup, so
-- the build writes video_type = '__unknown__' into all 31,947 rows with no error.
-- video_type is one of the four rollup dimensions, so every content-type-filtered
-- answer downstream would be wrong and nothing would say so.
--
-- It self-heals within the LIFETIME window (MIN 300 MAX 600), but the root cause
-- of the empty load is not established, so recovery cannot be assumed. The gate
-- below is the durable protection: a dimension that is 100% fallback is a failure,
-- not a data characteristic.
--
-- Probing content_current is what makes this precise -- it fails only when an id
-- that demonstrably EXISTS resolves to the fallback, which is unambiguous
-- staleness rather than a genuinely new content id on an unseen day.
-- ----------------------------------------------------------------------------

SELECT
    hostName()          AS replica,
    toString(status)    AS status,
    element_count,
    toString(last_successful_update_time) AS last_loaded
FROM clusterAllReplicas(default, system.dictionaries)
WHERE database = 'sonyliv' AND name = 'content_dict'
ORDER BY replica;

SELECT throwIf(
    (
        SELECT count()
        FROM sonyliv.content_current AS c
        WHERE dictGetOrDefault('sonyliv.content_dict', 'video_type', tuple(c.content_id), '') = ''
    ) > 0,
    'content_dict returns the fallback for content ids that exist in content_current: the dictionary is cold or stale on the replica serving this query. Run  SYSTEM RELOAD DICTIONARY sonyliv.content_dict  on every replica, confirm element_count is non-zero in the report above, and retry.'
);


-- ----------------------------------------------------------------------------
-- Guard 2: boundary sessions.
--
-- A session with events but no VideoSessionStart is dropped by the HAVING and
-- the JOIN below -- no error, no count, just missing viewers. The supplied
-- 12-day extract contains only whole sessions (all 10,866 have exactly one
-- start), so this has never fired. A single-day extract is cut at both ends and
-- will contain sessions that began the previous day.
--
-- Two failure modes compound for such a session: it is dropped here, and even
-- if it were kept it could never become active, because only VideoPlay and
-- resume set playing while a continuously-playing session emits only liveness
-- heartbeats. Whether those viewers should count, and from when, is a
-- judgement call against a private answer key. We refuse to guess and stop
-- instead.
--
-- The report runs first so the operator sees the number, then the gate fires.
-- ----------------------------------------------------------------------------

WITH scoped_sessions AS
(
    SELECT session_key
    FROM sonyliv.dirty_sessions
    WHERE last_ingested_at > toDateTime64OrZero({since_ingested_at:String}, 3, 'UTC')
)
SELECT
    count()                    AS boundary_sessions,
    sum(event_count)           AS boundary_events,
    min(first_event)           AS earliest,
    max(first_event)           AS latest
FROM
(
    SELECT
        session_key,
        count()        AS event_count,
        min(event_ts)  AS first_event
    FROM sonyliv.events_clean
    WHERE {full_scan:UInt8} = 1 OR session_key IN scoped_sessions
    GROUP BY session_key
    HAVING countIf(signal = 'session_start') = 0
);

WITH scoped_sessions AS
(
    SELECT session_key
    FROM sonyliv.dirty_sessions
    WHERE last_ingested_at > toDateTime64OrZero({since_ingested_at:String}, 3, 'UTC')
)
SELECT throwIf(
    {allow_boundary_sessions:UInt8} = 0
        AND
        (
            SELECT count()
            FROM
            (
                SELECT session_key
                FROM sonyliv.events_clean
                WHERE {full_scan:UInt8} = 1 OR session_key IN scoped_sessions
                GROUP BY session_key
                HAVING countIf(signal = 'session_start') = 0
            )
        ) > 0,
    'Sessions found with events but no VideoSessionStart -- these are silently excluded from interval state. See the count above. Decide the boundary-session policy, then pass allow_boundary_sessions=1 to proceed with them excluded.'
);


-- ----------------------------------------------------------------------------
-- Build.
-- ----------------------------------------------------------------------------

INSERT INTO sonyliv.active_intervals
(
    policy_version,
    clip_variant,
    session_start_date,
    session_key,
    user_key,
    interval_index,
    start_time,
    end_time,
    content_id,
    platform,
    country,
    video_type,
    state_revision
)
WITH
    {heartbeat_timeout_ms:UInt64} AS heartbeat_timeout_ms,

    -- The last instant we actually observed. Also the clip boundary.
    --
    -- THIS FULL SCAN IS DELIBERATE. DO NOT "optimise" IT. events_clean is
    -- ORDER BY (session_key, event_ts, ...), so event_ts is not the sort-key
    -- prefix and max() cannot use the primary index: measured on the service
    -- 2026-08-02, 901,348 rows / 7,210,784 bytes / 11.2 ms. A projection cannot
    -- help either -- events_clean is a SharedReplacingMergeTree and
    -- deduplicate_merge_projection_mode is `throw`, so ADD PROJECTION is
    -- refused on it.
    --
    -- The cheap alternative was measured and REJECTED. dirty_sessions carries
    -- max_event_time per session, and max(max_event_time) returns the identical
    -- value -- verified, both 2026-07-26 11:30:04.847 -- for 10,943 rows /
    -- 87,544 bytes / 2.6 ms. That is 82.4x fewer rows and 4.4x faster.
    --
    -- It is still the wrong trade. dirty_sessions is an append-only WORK QUEUE
    -- with no TTL today, but nothing in the schema stops it being pruned once
    -- processed -- and if it were, max(max_event_time) would silently go
    -- BACKWARDS. observation_horizon is the clip boundary, so a horizon that is
    -- too low drops real events from the answer with no error. Trading a
    -- 9-millisecond saving for a silent-wrong-answer coupling to a prunable
    -- table inverts this project's stated priority. events_clean is the
    -- authority for "what did we observe"; keep reading the authority.
    assumeNotNull((SELECT max(event_ts) FROM sonyliv.events_clean)) AS observation_horizon,

    -- Explicit empty-string test, NOT ifNull(toDateTime64OrNull(...), ...).
    -- See the note above Guard 1: OrNull returns the epoch for '', so the ifNull
    -- form silently resolves to 1970-01-01 and the build returns zero rows.
    if({evaluation_as_of:String} = '',
       observation_horizon + toIntervalMillisecond(heartbeat_timeout_ms),
       toDateTime64OrZero({evaluation_as_of:String}, 3, 'UTC')) AS evaluation_as_of,

    scoped_sessions AS
    (
        SELECT session_key
        FROM sonyliv.dirty_sessions
        -- Watermark on last_ingested_at, NOT on dirty_operation_id.
        -- dirty_operation_id is xxHash64(session_key, batch_id, row_seq) -- a
        -- deterministic identity for set-membership ("has this been applied?"),
        -- NOT a sequence. Measured on the live queue it spans 3.1e15 to 1.8e19
        -- with 49.7% of values above the UInt64 midpoint, so `> watermark` would
        -- select a pseudo-random half of the queue. last_ingested_at is the only
        -- monotonic column here.
        WHERE last_ingested_at > toDateTime64OrZero({since_ingested_at:String}, 3, 'UTC')
    ),

    -- Read events_clean directly and un-deduplicated. No dedup CTE.
    --
    -- Two reasons this is safe, both measured rather than assumed. The state
    -- machine is a fold of first-occurrence and last-writer-wins rules, so
    -- feeding it pause@T twice gives the same state as once -- and structurally,
    -- same_timestamp_assignments below groups by (session_key, event_ts) with
    -- max()/any(), which collapses duplicates before any state is derived.
    -- Second, of nine payload columns exactly one key in events_raw conflicts,
    -- on subtitle_language alone, which is neither a state input nor a
    -- dimension this table carries.
    --
    -- Cost of the alternative, measured warm on Cloud: reading through the
    -- events_dedup view is 0.59s / 24.4MB against 0.086s / 15.3MB here, because
    -- the view groups on all four sort-key columns and runs 16 argMax
    -- aggregates that do not prune away when you select two columns.
    --
    -- The un-deduplicated equivalence is asserted by a regression test. If that
    -- test starts failing, the conflict rate has risen and this shortcut is off.
    --
    -- events_clean is read directly in both places below rather than through a
    -- shared `source_events` CTE. Measured: the CTE form is no cheaper, and the
    -- duplicated WHERE is the plainer shape.
    --
    -- Scan budget, measured: read_rows is 2,704,045 = three passes over the
    -- 901,348-row table. Two are the state machine (anchors, then events joined
    -- to them). The third is the max(event_ts) subquery that derives
    -- evaluation_as_of -- event_ts is SECOND in events_clean's sort key, so a max
    -- cannot be answered from the primary index and has to scan. It reads one
    -- column, costing roughly 80 ms of the ~380 ms total.
    --
    -- That is the price of deriving the cutoff instead of hand-typing it, and it
    -- is worth paying: a mistyped literal drops events silently. If the scan ever
    -- matters, pass the horizon in as a parameter rather than reverting to a
    -- hardcoded as_of.

    -- Lifecycle anchors and session-static dimensions, taken from the FIRST
    -- VideoSessionStart. Anchoring here rather than per-event stops row drift
    -- (user 120 sessions, platform 95, content 1) changing attribution inside a
    -- session. row_version breaks ties deterministically.
    session_anchors AS
    (
        SELECT
            session_key,
            minIf(event_ts, signal = 'session_start')          AS lifecycle_start_time,
            minIf(event_ts, signal = 'session_end')            AS terminal_end_time,
            countIf(signal = 'session_end') > 0                AS has_terminal_end,
            argMinIf(user_key,    tuple(event_ts, row_version), signal = 'session_start') AS user_key,
            argMinIf(content_id,  tuple(event_ts, row_version), signal = 'session_start') AS content_id,
            argMinIf(platform,    tuple(event_ts, row_version), signal = 'session_start') AS platform,
            argMinIf(country,     tuple(event_ts, row_version), signal = 'session_start') AS country
        FROM sonyliv.events_clean
        WHERE event_ts <= evaluation_as_of
          AND ({full_scan:UInt8} = 1 OR session_key IN scoped_sessions)
        GROUP BY session_key
        HAVING countIf(signal = 'session_start') > 0
    ),

    -- Clip the stream to the first Start and the first End. A later Start or a
    -- post-End tail row stays in raw storage but cannot move interval state:
    -- 241 sessions carry 870 rows after their first End, and a terminal event
    -- should not reopen because anomalous tail rows exist.
    --
    -- NOTE: a plain INNER JOIN, deliberately. INNER ANY JOIN was measured here
    -- and returns ZERO intervals -- ClickHouse's ANY collapses the LEFT side to
    -- one row per key as well, discarding every event but one per session.
    events_through_first_end AS
    (
        SELECT
            e.session_key                AS session_key,
            e.event_ts                   AS event_ts,
            e.signal                     AS signal,
            a.lifecycle_start_time       AS lifecycle_start_time,
            a.user_key                   AS user_key,
            a.content_id                 AS content_id,
            a.platform                   AS platform,
            a.country                    AS country
        FROM sonyliv.events_clean AS e
        INNER JOIN session_anchors AS a USING (session_key)
        WHERE e.event_ts <= evaluation_as_of
          AND ({full_scan:UInt8} = 1 OR e.session_key IN scoped_sessions)
          AND e.event_ts >= a.lifecycle_start_time
          AND (NOT a.has_terminal_end OR e.event_ts <= a.terminal_end_time)
          AND (e.signal != 'session_start' OR e.event_ts = a.lifecycle_start_time)
    ),

    -- There is no source sequence within a millisecond, so collapse everything
    -- at one timestamp and apply deterministic stop-wins precedence. This
    -- GROUP BY is also where duplicate rows disappear.
    same_timestamp_assignments AS
    (
        SELECT
            session_key,
            event_ts,
            any(lifecycle_start_time)                       AS lifecycle_start_time,
            any(user_key)                                   AS user_key,
            any(content_id)                                 AS content_id,
            any(platform)                                   AS platform,
            any(country)                                    AS country,
            max(signal = 'session_start')                   AS has_start,
            max(signal = 'session_end')                     AS has_end,
            max(signal = 'background')                      AS has_background,
            max(signal = 'foreground')                      AS has_foreground,
            max(signal IN ('error', 'pause'))               AS has_play_stop,
            max(signal IN ('play', 'resume'))               AS has_play_start,
            max(signal IN ('play', 'resume', 'liveness'))   AS has_liveness_signal
        FROM events_through_first_end
        GROUP BY session_key, event_ts
    ),

    -- End wins both axes. Background wins visibility. Error and pause win
    -- playback. AppForegrounded restores visibility only -- it does NOT resume
    -- a paused player, which is the rule people get wrong most often.
    setters AS
    (
        SELECT
            *,
            multiIf(has_end OR has_background,  toInt8(-1),
                    has_start OR has_foreground, toInt8(1),
                    toInt8(0)) AS foreground_setter,
            multiIf(has_end OR has_play_stop,   toInt8(-1),
                    has_play_start,              toInt8(1),
                    toInt8(0)) AS playing_setter
        FROM same_timestamp_assignments
    ),

    state_after_assignment AS
    (
        SELECT
            *,
            max(has_start) OVER state_window AS lifecycle_started,
            max(has_end)   OVER state_window AS terminal_end_seen,
            argMaxIf(foreground_setter, event_ts, foreground_setter != 0) OVER state_window AS foreground_state,
            argMaxIf(playing_setter,    event_ts, playing_setter    != 0) OVER state_window AS playing_state
        FROM setters
        WINDOW state_window AS
        (
            PARTITION BY session_key ORDER BY event_ts
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
    ),

    -- A heartbeat only renews the lease when the viewer is already started, not
    -- ended, foregrounded and playing. Heartbeats received while paused or
    -- backgrounded do not keep a viewer counted.
    eligible_signals AS
    (
        SELECT
            *,
            has_liveness_signal
                AND lifecycle_started = 1
                AND terminal_end_seen = 0
                AND foreground_state  = 1
                AND playing_state     = 1 AS is_eligible_signal
        FROM state_after_assignment
    ),

    -- The default on leadInFrame is what handles an open session: the last row
    -- gets a synthetic next-event far in the future, and least() below clamps
    -- the interval to last_eligible_signal + timeout.
    leased_state AS
    (
        SELECT
            *,
            maxIf(event_ts, is_eligible_signal) OVER state_window AS last_eligible_signal,
            leadInFrame(
                event_ts, 1,
                evaluation_as_of + toIntervalMillisecond(heartbeat_timeout_ms)
            ) OVER full_window AS next_event_time
        FROM eligible_signals
        WINDOW
            state_window AS
            (
                PARTITION BY session_key ORDER BY event_ts
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ),
            full_window AS
            (
                PARTITION BY session_key ORDER BY event_ts
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            )
    ),

    candidate_segments AS
    (
        SELECT
            session_key,
            user_key,
            lifecycle_start_time,
            content_id,
            platform,
            country,
            event_ts AS start_time,
            least(
                next_event_time,
                last_eligible_signal + toIntervalMillisecond(heartbeat_timeout_ms)
            ) AS end_time
        FROM leased_state
        WHERE lifecycle_started = 1
          AND terminal_end_seen = 0
          AND foreground_state  = 1
          AND playing_state     = 1
          AND last_eligible_signal > toDateTime64(0, 3, 'UTC')
          AND event_ts < last_eligible_signal + toIntervalMillisecond(heartbeat_timeout_ms)
    ),

    nonempty_segments AS
    (
        SELECT * FROM candidate_segments WHERE end_time > start_time
    ),

    -- Merge touching and overlapping segments into maximal islands, so one
    -- continuous stretch of watching is one row rather than one row per event.
    marked_islands AS
    (
        SELECT
            *,
            start_time > max(end_time) OVER
            (
                PARTITION BY session_key ORDER BY start_time, end_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS starts_new_island
        FROM nonempty_segments
    ),

    numbered_islands AS
    (
        SELECT
            *,
            sum(starts_new_island) OVER
            (
                PARTITION BY session_key ORDER BY start_time, end_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS island_number
        FROM marked_islands
    ),

    normalized_intervals AS
    (
        SELECT
            session_key,
            island_number,
            any(user_key)             AS user_key,
            any(lifecycle_start_time) AS lifecycle_start_time,
            any(content_id)           AS content_id,
            any(platform)             AS platform,
            any(country)              AS country,
            min(start_time)           AS start_time,
            max(end_time)             AS end_time
        FROM numbered_islands
        GROUP BY session_key, island_number
    ),

    -- Emit both clip variants. do_clip=1 truncates at the last instant we
    -- actually observed; do_clip=0 lets an open session's lease run past it.
    -- Neither is provably right against a private answer key, so both exist and
    -- the choice is made at read time, explicitly.
    clip_expanded AS
    (
        SELECT
            n.*,
            v.do_clip AS do_clip,
            if(v.do_clip = 1, least(n.end_time, observation_horizon), n.end_time) AS resolved_end_time
        FROM normalized_intervals AS n
        CROSS JOIN (SELECT arrayJoin([0, 1]) AS do_clip) AS v
    )

SELECT
    {policy_version:String}                       AS policy_version,
    if(do_clip = 1, 'clipped', 'unclipped')       AS clip_variant,
    toDate(lifecycle_start_time, 'UTC')           AS session_start_date,
    session_key,
    user_key,
    toUInt16(row_number() OVER (
        PARTITION BY do_clip, session_key
        ORDER BY start_time, resolved_end_time
    ))                                            AS interval_index,
    start_time,
    resolved_end_time                             AS end_time,
    content_id,
    platform,
    country,

    -- content_dict is COMPLEX_KEY_HASHED, so the key MUST be a tuple. A simple
    -- key would be coerced to UInt64 and every lookup of the catalogue's one
    -- negative id (-987654322) would throw rather than miss. Called once and
    -- aliased; calling dictGetOrDefault twice to test emptiness relies on the
    -- planner eliminating the duplicate.
    if(empty(resolved_video_type), '__unknown__', resolved_video_type) AS video_type,

    {state_revision:UInt64}                       AS state_revision
FROM
(
    SELECT
        *,
        dictGetOrDefault('sonyliv.content_dict', 'video_type', tuple(content_id), '__unknown__') AS resolved_video_type
    FROM clip_expanded
    WHERE resolved_end_time > start_time
)
SETTINGS
    -- Measured on Cloud: 294ms / 89.12 MiB against 295ms / 111.14 MiB on the
    -- default algorithm, identical output. Both join inputs are already ordered
    -- on session_key, so the merge join skips a sort the hash join has to do.
    -- It does NOT remove the second scan of events_clean -- read_rows stays at
    -- 2x the table -- so a single-pass rewrite still has value beyond this.
    join_algorithm = 'full_sorting_merge',

    -- Without a token, re-running this file appends a second copy of every
    -- interval. The table's deduplication window makes a repeat a no-op for 30
    -- days; vary the token when the run is genuinely new.
    insert_deduplication_token = {insert_token:String},

    -- Scan and wall-clock caps. Cloud leaves both unlimited by default.
    max_execution_time = 300,
    max_rows_to_read = 1000000000,
    timeout_before_checking_execution_speed = 0;
