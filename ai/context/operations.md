# screwfast — operating contract (for humans and agents)

This is the standing guide to how this site is deployed and operated.
Instance facts (live URLs, workspace, the secrets it uses) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `03-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the site without any
other source.

## What this system is

A marketing site and its documentation on the ScrewFast template
(mearashadowfax/ScrewFast) — Astro, Tailwind CSS, Preline UI and Starlight;
marketing pages in English and French, docs in seven languages — on
Cloudflare alone, expressed as an Orun component-native desired-state repo.

- **`apps/web`** — the site: `astro build` (`output: 'static'`) writes every
  marketing page (`/` and `/fr/`), product, post, insight and docs page to
  `dist/`, optimising every image with sharp, and Starlight's Pagefind
  indexes the docs into `dist/pagefind`; `process-html.mjs` then minifies
  the pages in place. It deploys as Workers Static Assets behind one small
  Worker (`worker/index.ts`) that answers requests matching no file with the
  site's 404 page — the French one under `/fr/`. The template's security
  headers are `public/_headers`. Its tests (`src/test`, vitest over Astro's
  container API) and `astro check` are not run by a pull request's lanes,
  which build and dry-deploy the site: run `pnpm typecheck`, `pnpm lint` and
  `pnpm test` before you push. There is no database and no runtime secret.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  deploy-time wrangler renderer for workers that take wiring.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and dry-deploy, nothing deploys.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` builds once per environment (`astro build`, the docs' index
   and the minifier → `dist/`), then `wrangler deploy` ships
   `screwfast-web-<env>` with `apps/web/wrangler.jsonc` — the Worker and
   `dist/` as its assets — and a smoke test fetches `/` (its French
   alternate linked), `/products/`, the docs' welcome page and their search
   index, and checks that an unknown path is a 404 from it, the French 404
   page under `/fr/`.
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane applied. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "site
  converged"; probe the URLs instead.
- A change to `intent.yaml`'s `environments` maps to no component and
  redeploys nothing on its own. Land it with a change under `apps/web`.
- `apps/web/wrangler.jsonc` is the one Worker config: the build reads none
  of it, and the deploy ships the Worker and `dist/` with it. A binding, a
  variable or a compatibility change goes there.
- Canonical, hreflang and Open Graph links, the sitemap and robots.txt are
  absolute, built for the origin each deploy serves: the environment's
  `SITE_URL` (intent.yaml), else its workers.dev URL (`buildCommand` sets
  `PUBLIC_SITE_URL`). A local build uses the domain placeholder in
  `apps/web/astro.config.mjs`.
- Pages are directories (`/products/<id>/`): a path without its trailing
  slash redirects to it (`html_handling: auto-trailing-slash`).
- The build downloads the demo's Unsplash photos (avatars, product shots)
  and optimises them with the rest; a build with no network fails there.
- The site's name is `apps/web/src/site.ts`, and every page's chrome and
  copy reads it. The demo content under `apps/web/src/content` is the
  template's writing as its fictional company and says that company's name
  until it is replaced.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (Workers deploy
  scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per run from the
  workspace's Cloudflare connection. No long-lived values at rest; nothing
  to rotate by hand.
- Inspect by NAME only: `orun secrets list --org <ws> --project` and
  `--env stage|prod`. No tooling in this repository prints a secret value,
  and no document in `ai/context/` may contain one.
- The site needs no runtime secret: it is static, and its contact form is
  the template's demo, which submits nowhere.

## Verifying the system

```bash
# the site on each environment (also recorded, probed, in deployment.md)
curl -s -o /dev/null -w '%{http_code}\n' https://screwfast-web-stage.your-workers-subdomain.workers.dev/
curl -s -o /dev/null -w '%{http_code}\n' https://screwfast-web-prod.your-workers-subdomain.workers.dev/welcome-to-docs/

# workspace readiness (integrations + repository link)
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| change the site's name | `apps/web/src/site.ts`; merge — titles, logos' labels, footer, Open Graph, manifest, the docs' title and the copy follow |
| change the marketing copy | `apps/web/src/copy/en.ts` and `fr.ts` (a key missing from `fr.ts` fails `astro check`); features, pricing and the FAQ in `apps/web/src/data_files/` (`fr/` for French); merge |
| add a product, post or insight | a Markdown file in `apps/web/src/content/{products,blog,insights}/en/` and its French twin in `…/fr/`, with the front matter the others carry; merge |
| add a docs page | a `.mdx` in `apps/web/src/content/docs/` (and per language under `de/`, `es/`, `fa/`, `fr/`, `ja/`, `zh-cn/` — a missing one falls back to English); the sidebar is `starlight({ sidebar })` in `apps/web/astro.config.mjs`; merge — it is searchable on the next build |
| add a page | `apps/web/src/pages/<route>.astro` (and `pages/fr/<route>.astro`), merge — it builds to a static file |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| deploy by hand | Orunbase's Deploy button, or `gh workflow run ci.yml --ref main -f environment=<env> [-f component=<a,b>]` — the named components (blank: every one) run in that environment as a merge runs them; started off `main` it is refused |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare; set `SITE_URL` for the environment in `intent.yaml` so the deployment record probes it — the next deploy builds its links for it — and replace the placeholder `screwfast.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod), in `apps/web/astro.config.mjs` and in the contact address with it (README, "Custom domain") |
| a redirect or a response header | `apps/web/worker/index.ts`, or `apps/web/public/_headers` / a `_redirects` file there (the assets upload honours both) |
| add a runtime secret | `orun secrets set <KEY> --org <ws> --env <env>` |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `03-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 03-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Structural changes (a form handler, an API, a data store, a CMS) follow the
same contract that deployed the site: add a component under `apps/`,
`infra/` or `packages/` with a `component.yaml`, land it as a pull request,
and the convergence run applies it.
