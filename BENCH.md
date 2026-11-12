# Build-deploy benchmark fixture: static medium (react-native-website, Docusaurus)

## Source

- Upstream: https://github.com/react/react-native-website at `ff1cdf3bf674eb7288f6a8807df5c5d4979f07b9` (2026-11-12). Code MIT (`LICENSE`), docs CC BY 4.0 (`LICENSE-docs`).
- This repo: https://github.com/build-deploy-bench/react-native-website-example (private, independent copy). The first commit is the unmodified upstream.
- Fixture layout from commit `a2fa6ae856d749a7ee06c9ef608ba8675c0b7eea` (the static fixture convention in the harness `guides/fixtures.md`; reference fixture `vuejs-docs-static`).
- Output: `website/build`, 453 MB in 6,740 files (12 doc versions). About 2,970 files differ between two builds of the same commit (hashed asset names); this is accepted.

## Patches

1. Upstream GitHub Actions workflows removed.
2. `website/docusaurus.config.ts`:
   - `showLastUpdateTime: false`. It reads the git history of each doc, and the build fails without `.git`. Fly and Vercel upload a source tree without `.git`.
   - `isProductionDeployment = false` and `isDeployPreview` only from `PREVIEW_DEPLOY`. Upstream reads the Netlify and Vercel env: a Vercel production deploy turns on webpack `concatenateModules` (slower, more memory), and a Vercel preview deploy builds only 3 doc versions. With the patch, every provider builds the same configuration as an upstream local build. With `concatenateModules` on, a local 4-CPU build ran out of memory at 6.7 GB.
3. Node and Yarn pinned. Node 24.22.3 on every provider: `engines.node` `24.x` (Vercel takes it and ignores the project setting; it resolved to 24.22.3), `.node-version` `24.22.3` (Render) and `node:24.22.3-slim` (Railway, Fly). Yarn 1.22.22 is checked in at `.yarn/releases/yarn-1.22.22.cjs` (the GitHub release file, SHA-256 `1ba910c8…5105`), and `.yarnrc` sets `yarn-path`, so every global Yarn 1 runs it. The `.cjs` name is needed because the root `package.json` has `"type": "module"`.
4. `vercel.json` replaced. Upstream's file runs `yarn build:vercel` with a deep clone and has about 550 redirects; the new file runs the same commands as the other providers (preset `docusaurus-2`) with `cleanUrls: true`, because Docusaurus writes `/docs/x` as `docs/x.html` and Vercel does not try `.html` without it. Render and Caddy serve these paths as they are.
5. Added `bench/build.sh`, `bench/serve.sh`, `Dockerfile`, `Caddyfile`, `.dockerignore`, `.node-version`, `fly.toml`, and the touch file `docs/bench-touch.md` (an unlisted page, because the runner replaces the whole file). `Dockerfile`, `Caddyfile` and `serve.sh` are copies of the reference fixture with a different build stage and publish directory.

## Commands

| Step | Command | Markers |
|---|---|---|
| Toolchain | `node --version`, `yarn --version` (before the install marker: on Render the first `node` call installs Node) | |
| Install | `./bench/build.sh install` = `yarn install --frozen-lockfile --non-interactive` | `::bench::install_start` / `::bench::install_done` |
| Build | `./bench/build.sh build` = `yarn build` (Docusaurus build, then `update-redirects` on the Netlify `_redirects` file), then write `website/build/version` | `::bench::build_start` / `::bench::build_done` |
| Start (Caddy image only) | `sh /bench/serve.sh` | `::bench::start` / `::bench::listening` |
| Health | `GET /` | |

Every `::bench::` marker ends with the wall-clock time in epoch milliseconds (the Caddy image adds `coreutils`, because BusyBox `date` has no milliseconds).

`/version` is the file `website/build/version` with no extension, `{"commit","run"}`, served without a rewrite rule. `BENCH_RUN_ID` reaches the build on Render (service env) and Vercel (`--build-env`). In the Caddy image, `serve.sh` writes the file again with the runtime `BENCH_RUN_ID` and `RAILWAY_DEPLOYMENT_ID` and keeps the built commit. The commit is the first of `BENCH_COMMIT`, `RENDER_GIT_COMMIT`, `RAILWAY_GIT_COMMIT_SHA`, `VERCEL_GIT_COMMIT_SHA`, then `git rev-parse HEAD`, then `unknown`. A Vercel CLI upload has no commit, so the harness passes `--build-env BENCH_COMMIT`.

Memory: a local build on 2 CPUs (`node:24-slim`, Docker cgroup) took 89 s with a peak of 6.1 GB anonymous memory (6.6 GB with page cache). Every builder used here has at least 8 GB (Render Starter 8 GB, Vercel standard 8 GB, Fly builder 8 GB, Railway Metal). No memory setting is applied.

Docker image (`Dockerfile`): build stage `node:24.22.3-slim`, final stage `caddy:2.11.9-alpine` plus `coreutils`. About 810 MB uncompressed (453 MB of site).

## Providers

### Render

- Workspace `tea-dbmbhbg8v5cc73e4m0jg` (Pro). Static site `srv-dbqub3dckfvc738ii3n0` `bdb-rn-website`, https://bdb-rn-website.onrender.com. Build pipeline `starter`. Static sites have no instance plan and no region. Auto-deploy off.
- Build command `./bench/build.sh all`, publish path `website/build`. No routes or headers.
- Env: `BENCH_RUN_ID` (set by the harness), `SKIP_INSTALL_DEPS=true`. Without it, Render runs its own `yarn install` before the build command (40 s on the first deploy), outside the markers.
- Setup deploys (old layout, `/version` through a rewrite to `version.json`): `dep-dbqub3lckfvc738ii4m0` (creation deploy of `ab029f8`, without `SKIP_INSTALL_DEPS`) went live, and `/version` returned the right SHA and run.
- Deploy `dep-dbque9utlv9c739jancg` (same commit, cache kept, `SKIP_INSTALL_DEPS=true`, new `BENCH_RUN_ID`): 452 MiB cache restore in 16 s, install 4 s (Render installs Node 24.22.3 on the first `node` call, inside the install markers), build 63 s, upload 33 s, then live. `/version` returned the old run ID for about 20 s after `live` (`cf-cache-status: HIT` despite `no-store`), then the new one.

### Railway

- Workspace `d535606c-49a7-4a6c-9e29-ce73b5f01428` (paid). Project `bdb-rn-website` `aee9daaa-495b-4198-8856-5d3952a7784c`, environment `production` `25c70af0-7e81-48f0-a9ee-3c812860a767`, service `bdb-rn-website` `bb75c6da-6ea9-42b3-83c8-3165c7407854`, https://bdb-rn-website-production.up.railway.app
- Source `build-deploy-bench/react-native-website-example` branch `main`. `dockerfilePath: Dockerfile` (the instance still reports `builder: RAILPACK`, but the build log shows `load build definition from Dockerfile`). Health check `/`. One replica, default region. No variables.
- Auto-deploy disabled after `serviceConnect`, confirmed with `serviceInstanceAutoDeployStatus`.
- Setup deploy `7ae14008-1315-49e5-8b4e-d7a386ecc490` (the connect deploy of `ab029f8`, old layout) succeeded: install 45 s, build 98 s, then image export; all six markers present. `/version` returns the right SHA and the deployment ID.

### Vercel

- Team `build-deploy-bench` `team_oVjpdXNb0OhSfAzc6FSNjen8`. Project `bdb-rn-website` `prj_JiyocyHO49GdRziz0fImgPVNrYlB`, https://bdb-rn-website.vercel.app. No Git link; deploys upload a `git archive` with `vercel deploy --prod`. Build machine: the team default (elastic selection), the same as the other projects; every build so far logged `4 cores, 8 GB (Standard Build Machine)` and ran in `cle1`, not `iad1`. Node 24.22.3 (from `engines.node`).
- Setup deploy `dpl_3sKbuFa5Gr1W9n1Y29fX76RZQ9cy` (old layout, without `cleanUrls`): READY, install 41 s, build 108 s, `Deploying outputs` 2.4 s. `/version` had the run ID but commit `unknown` (no `BENCH_COMMIT`), and `/docs/*` returned 404, which led to `cleanUrls`.
- The build cache (about 416 MB, `node_modules` and the Docusaurus cache) is created and uploaded after READY and takes about 47 s. A deploy that starts before the upload ends gets `Previous build caches not available`.

### Fly.io

- Org `personal`. App `bdb-rn-website`, https://bdb-rn-website.fly.dev. One Machine, `iad`, shared-cpu-1x with 256 MB, always on. Health check `/`.
- Deploy: `flyctl deploy --config fly.toml -a bdb-rn-website --remote-only --depot=false --ha=false --yes --strategy bluegreen --build-arg BENCH_COMMIT=<sha> --env BENCH_RUN_ID=<id>` from a `git archive`. The build context is 182 MB in 3,571 files; flyctl warns about it.
- Builder: the org's remote builder `fly-builder-rosy-headland-8386` (shared-cpu-8x, 8 GB), shared by all fixtures.
- Setup deploy of `ab029f8` without the builder lock, with four other deploys on the builder: `yarn install` failed with `ESOCKETTIMEDOUT` on the 20 MB `react-native-0.87.1.tgz` after 9 minutes of network retries, and the build step then hung, so the deploy was stopped. No release.
- Setup deploy of `a2fa6ae` under the builder lock: install 150 s, build 590 s, image 527 MB. Machine `86550d6c764d08` updated, `/version` returns the right SHA and run. The build step is about 5 times slower than on the other builders (2 to 4 CPU) although the builder has 8 shared CPUs.

## Matrix check (2026-11-12, `m-static-medium-1`)

One cold and one warm run per provider with `matrix/run.py`, Vercel and Fly each under the shared build lock. Times in seconds.

| Provider | Run | Result | install | build | build_total | e2e |
|---|---|---|---|---|---|---|
| Render | cold | live | 43 | 112 | 200 | 226 |
| Render | warm | live | 1 | 69 | 124 | 149 |
| Railway | cold | SUCCESS | 44 | 87 | 156 | 191 |
| Railway | warm | SUCCESS (observed cold) | 43 | 87 | 155 | 184 |
| Vercel | cold | READY | 47 | 131 | 190 | 195 |
| Vercel | warm r1 | READY (no cache) | 45 | 143 | 200 | 206 |
| Vercel | warm r2 | READY | 1 | 68 | 84 | 90 |
| Fly | cold | failed | 154 | killed | | |
| Fly | warm | ok | 0 (cached layer) | 479 | 676 | 700 |

- Vercel warm r1 started 4 s after the cold run was READY, before the cold run's build cache was uploaded, so it ran without a cache. r2 restored it.
- Railway reran the install layer on the warm run.
- Fly cold: the build step was killed for out of memory (exit 137) after 319 s. The idle builder has 6.9 GB available and no swap, and this build needs about 6.1 GB on 2 CPUs and probably more with 8. Two of three Fly builds under the lock passed. The Fly source step (context upload to the builder) took 126 to 181 s.
