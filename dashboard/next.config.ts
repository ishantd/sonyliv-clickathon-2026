import type { NextConfig } from "next";

/*
  Static export, so `next build` emits plain HTML/CSS/JS into ./out and the Go
  binary serves it from an embed.FS. That keeps the deploy to ONE artifact: no
  second Node process on the box, no reverse proxy, and the existing deploy script
  needs no change.

  Consequences, all of which this app already lives within — the full list of
  unsupported features is in the bundled doc at
  node_modules/next/dist/docs/01-app/02-guides/static-exports.md:

  - No rewrites. The usual trick of proxying /api to the Go service through
    next.config is unavailable, and using it errors even under `next dev`. So the
    API base is an env var instead: empty in production (same origin, served by
    Go) and set to Go's address in .env.development. That cross-origin dev hop is
    why the Go server takes an explicit --cors-origin flag.
  - No Route Handlers, Server Actions, cookies, or Image Optimization. None are
    wanted: the Go service IS the API, and this is a tool with no images.
  - Every page is a Client Component fetching through SWR, which is the pattern
    the static-export guide recommends for client-side data.

  trailingSlash keeps the emitted layout at /manual/index.html rather than
  /manual.html, so Go's static file handler resolves a bare /manual with no
  special casing.
*/
/*
  basePath — what lets this app share one host and one port with LibreChat.

  The demo box terminates TLS once, on :443, and LibreChat has to own `/` there:
  its assets, its /api routes and its SSE stream are all absolute from the root,
  and there is no supported way to rebase them. Two upstream requests for exactly
  that are open and unanswered — danny-avila/LibreChat#5702 and discussion #2406 —
  and DOMAIN_CLIENT/DOMAIN_SERVER only affect absolute URLs it generates
  (OAuth callbacks, email), not where the client fetches its bundle from.

  This app has no such problem, because basePath is a first-class Next feature. So
  the app that CAN move is the one that moves: LibreChat keeps the root untouched
  and this one goes to a prefix, which needs no sub_filter rewriting of hashed
  asset names and no extra security-group rule.

  Set at build time, not hardcoded, for two reasons. `next dev` must stay at `/` or
  local development gains a prefix nobody wants. And the prefix belongs to the
  deployment, not to the app — a second box could mount it elsewhere.

    NEXT_PUBLIC_BASE_PATH=/build npm run build     # behind nginx
    npm run build                                  # standalone at root

  NEXT_PUBLIC_API_BASE must be set to the SAME value, and that is not redundant:
  basePath rewrites links and asset URLs, but fetch() calls in lib/api.ts are
  strings this app builds itself, so Next does not touch them. Leave it empty here
  and the app requests /api/... at the root — which on the demo box is LibreChat's
  API, not ours. It would not 404; it would reach the wrong service.
*/
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,

  // Empty string is the "no prefix" value; Next rejects "/" as a basePath.
  ...(basePath ? { basePath, assetPrefix: basePath } : {}),

  // Served from a Go binary, not a CDN with an image pipeline.
  images: { unoptimized: true },

  // Fail the build on a type error rather than shipping one to the box.
  //
  // There is deliberately no `eslint` key: Next 16 removed it from NextConfig
  // (and removed `next lint`), so linting is its own step — `npm run lint`, which
  // runs eslint against eslint.config.mjs.
  typescript: { ignoreBuildErrors: false },
};

export default nextConfig;
