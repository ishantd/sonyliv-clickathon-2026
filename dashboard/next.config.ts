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
  basePath — supported, and deliberately UNUSED by the demo deployment.

  This app used to be built with NEXT_PUBLIC_BASE_PATH=/build so it could share one
  host with LibreChat, which has to own `/`: LibreChat's assets, its /api routes and
  its SSE stream are all absolute from the root, and there is no supported way to
  rebase them. Two upstream requests for exactly that are open and unanswered —
  danny-avila/LibreChat#5702 and discussion #2406 — and DOMAIN_CLIENT/DOMAIN_SERVER
  only affect absolute URLs it generates (OAuth callbacks, email), not where the
  client fetches its bundle from.

  That LibreChat constraint is still true. It stopped being OUR problem when the demo
  gained a second hostname: LibreChat now lives on chat.fastandfurious.live and this
  app owns the apex root. The deployed build is therefore a plain `npm run build` with
  no prefix, and deploy/nginx/sonyliv.conf proxies `/` straight through with no
  prefix-stripping.

  Splitting on Host beat splitting on path for a reason worth keeping written down:
  under a prefix, NEXT_PUBLIC_API_BASE had to be held in lockstep with basePath, and
  if it ever drifted this app's /api/... calls reached LibreChat's API instead of ours
  — not a 404, a wrong service, which is a far worse way to fail. On its own hostname
  that failure mode cannot exist at all.

  The mechanism stays, because the prefix belongs to the deployment and not to the
  app: another box may need to mount this under one, and `next dev` must stay at `/`
  either way.

    npm run build                                  # what the demo ships: apex root
    NEXT_PUBLIC_BASE_PATH=/build npm run build     # behind a path prefix

  If you do set a prefix, set NEXT_PUBLIC_API_BASE to the SAME value. That is not
  redundant: basePath rewrites links and asset URLs, but the fetch() calls in
  lib/api.ts are strings this app builds itself, so Next never touches them.
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
