-- 013_demo_seed_catalogue.sql — give sonyliv_demo a catalogue, and nothing else.
--
-- Runs as sonyliv_svc (SELECT on sonyliv_unseen, INSERT on sonyliv_demo — both
-- granted), so this one does NOT need run-as-admin.sh:
--
--   CLICKHOUSE_DATABASE=sonyliv_demo ./ingest/concurrency/ch.sh \
--       --file ingest/sql/manual/013_demo_seed_catalogue.sql
--
-- WHY THE CATALOGUE AND NOTHING ELSE. sonyliv_demo exists to start empty and fill up
-- while someone watches — that is the entire point of a live demo database, and
-- 012 explains why none of the other three can be that. But "empty" has to stop short
-- of the catalogue, because content_id is enriched through content_dict at rollup time.
-- With no catalogue every generated session resolves to '__unknown__' and the title,
-- category and video-type panels render one bar labelled "unknown". The traffic would be
-- live and the breakdowns would be meaningless.
--
-- So: catalogue seeded, event tables empty. The demo's whole event history is whatever
-- the simulator has produced.
--
-- COPIED FROM sonyliv_unseen, NOT RE-PARSED FROM THE CSV. Two reasons. The unseen day's
-- catalogue is the newer of the two — it carries show_name, which the July extract's
-- does not — so the demo exercises the same columns the evaluation set does. And an
-- INSERT SELECT inside one service cannot disagree with its source the way a second CSV
-- parse can; there is no second code path to keep correct.

INSERT INTO sonyliv_demo.content_dim
SELECT * FROM sonyliv_unseen.content_dim;

-- The dictionary caches per replica and loads lazily, so a freshly seeded
-- content_dim is NOT visible to a dictGet until something triggers a load — and
-- the first thing to trigger it may be the demo itself, mid-presentation.
--
-- This is not hypothetical here. On this service we watched the two replicas
-- disagree: one reported LOADED with element_count = 33464 while the other
-- reported LOADED with element_count = 0, at the same instant, and every
-- dictGetOrDefault routed to the cold one silently returned the default.
--
-- SYSTEM RELOAD DICTIONARY is synchronous, so issuing it here closes the window
-- deliberately instead of leaving it to LIFETIME. ON CLUSTER default because the
-- cache is per-replica and a local reload only fixes the replica that happens to
-- serve this statement.
SYSTEM RELOAD DICTIONARY ON CLUSTER default sonyliv_demo.content_dict;

-- Verification. Both must hold before the demo is trusted:
--
--   SELECT count() FROM sonyliv_demo.content_dim;              -- 33,326
--   SELECT count() FROM sonyliv_demo.events_raw;               -- 0
--
--   -- and the dictionary, ACROSS REPLICAS -- never check this on one node:
--   SELECT hostName(), toString(status), element_count
--   FROM clusterAllReplicas(default, system.dictionaries)
--   WHERE database = 'sonyliv_demo' AND name = 'content_dict';
--   -- every row LOADED with the same non-zero element_count
