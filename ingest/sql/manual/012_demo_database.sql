-- 012_demo_database.sql — the writable demo database the simulator writes into.
--
-- RUN THIS AS AN ADMIN, once, before `CLICKHOUSE_DATABASE=sonyliv_demo make schema`.
-- Same reason as 009: sonyliv_svc holds no CREATE DATABASE and no GRANT OPTION, so it
-- can neither create this database nor grant itself rights on it. Verified —
-- `CREATE DATABASE sonyliv_demo` as sonyliv_svc returns:
--
--     Code: 497. DB::Exception: sonyliv_svc: Not enough privileges. To execute this
--     query, it's necessary to have the grant CREATE DATABASE ON sonyliv_demo.*
--
--   ./ingest/sql/manual/run-as-admin.sh ingest/sql/manual/012_demo_database.sql
--
-- WHY A FOURTH DATABASE. The demo needs a target that is *live* — a curve that starts
-- empty and builds while someone watches it — and none of the three existing databases
-- can be that:
--
--   sonyliv          the sibling delta/checkpoint pipeline. Not ours to write into.
--   sonyliv_unseen   the sealed evaluation day. Writing here would destroy the one
--                    number the submission is graded on.
--   sonyliv_prod     the July extract plus every load test ever run against it. Its
--                    ungrouped peak is 146,918, set by a 100,000-session load test on
--                    2026-08-01 — so a live demo curve would be a flat line at the
--                    bottom of an axis scaled to that spike, and the canonical hot-hour
--                    2,305 sits somewhere in the middle of the same series.
--
-- So this database exists to be *empty*, except for the catalogue. Its whole content is
-- whatever the simulator has produced since it was created, which is exactly what makes
-- a live demo legible.
--
-- sonyliv_prod is NOT dropped and NOT changed. It keeps the graded July extract and the
-- 2,305 reference figure, and stays in the dashboard's dataset picker as a read-only
-- option. Only the write target moves.

CREATE DATABASE IF NOT EXISTS sonyliv_demo;

-- The service account, mirroring its sonyliv_unseen grant exactly. DROP TABLE is
-- included deliberately: this is the one database that is meant to be re-creatable from
-- nothing, so `make schema` must be able to tear a table down and rebuild it. That is
-- the opposite of the argument for withholding DROP TABLE on sonyliv_prod.
GRANT SELECT, INSERT, ALTER,
      CREATE TABLE, CREATE VIEW, CREATE DICTIONARY,
      DROP TABLE, DROP VIEW, DROP DICTIONARY,
      TRUNCATE, dictGet
  ON sonyliv_demo.* TO sonyliv_svc;

-- The MCP reader, mirroring 009 object for object.
--
-- The list is restated rather than widened to `sonyliv_demo.*`, because the whole point
-- of 009 is that the boundary is enumerated: the six objects carrying user identity
-- (events_raw, events_clean, events_dedup, events_raw_to_clean_mv, fleet_sessions,
-- session_intervals) are absent from this list, and a wildcard would silently hand the
-- model every one of them in the new database.
GRANT SELECT ON sonyliv_demo.serving_concurrency_live   TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_concurrency_minute TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_watermark          TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_watermark_history  TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_live_total         TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_live_content       TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_minute_current     TO sonyliv_mcp;
GRANT SELECT ON sonyliv_demo.serving_drop_signal        TO sonyliv_mcp;
GRANT dictGet ON sonyliv_demo.content_dict              TO sonyliv_mcp;

-- Verification, as admin:
--
--   SELECT name FROM system.databases WHERE name = 'sonyliv_demo';   -- one row
--   SHOW GRANTS FOR sonyliv_svc;   -- a sonyliv_demo.* line matching sonyliv_unseen's
--   SHOW GRANTS FOR sonyliv_mcp;   -- nine sonyliv_demo lines, no events_* among them
--
-- Then, as sonyliv_svc:
--
--   CLICKHOUSE_DATABASE=sonyliv_demo make -C ingest schema
--   ./ingest/sql/manual/013_demo_seed_catalogue.sql   (see that file)
