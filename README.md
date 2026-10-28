# screwfast

Vercel's [ScrewFast](https://github.com/mearashadowfax/ScrewFast) template —
an Astro, Tailwind CSS and Preline UI marketing site for a hardware and
construction company: a home page with features, pricing, FAQ and
testimonials, products and a page per product, services, contact, a blog and
customer insights, in English and French, and a Starlight documentation
section in seven languages with its full-text search — running on
**Cloudflare Workers + Static Assets**, and packaged as an **Orun baseline**:
one command takes a new site from nothing to live on stage and prod, in its
own repository, under its own name.

ScrewFast builds fully static: `astro build` writes every marketing page,
product, post, insight and docs page to `dist/`, optimising every image with
sharp, Starlight's Pagefind indexes the docs into `dist/pagefind`, and the
template's minifier rewrites the pages in place. That folder is uploaded as
Workers Static Assets with one small Worker in front for what matches no
file — the site's 404 page, the French one under `/fr/`, as the template's
Vercel rewrite served it; no adapter and no server code. The pages, the
copy, the languages and the docs do not change; the site's name moves into
one module that the copy reads, and each deploy builds for its own origin.
What the baseline adds is everything needed to make a copy of it somebody
else's — built the way [cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) is.
See [`specs/epics/screwfast`](specs/epics/screwfast/README.md) for the
design, the milestones and the as-built status.

## Instantiating a site

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/screwfast
cd screwfast
orun new --blueprint repo-blueprint.yaml --out ~/sites/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`screwfast` → Build). Two phases — `01-product` (the repository
created, then the whole site in one pull request, deployed to stage and prod
and smoke-tested) and `03-docs` (the live deployment recorded) — each landing
one pull request in the new repository. **[BOOTSTRAP.md](BOOTSTRAP.md)** is the
operator guide; [docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **site only** — the app and its tests, its
CI, its tooling, a README of its own and its operating contract — renamed
throughout to the site's name, repository and Cloudflare Worker. None of this
repository's machinery ships.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The site's README and context pack | `.baseline/product/README.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

### The template's name is this repository's slug

ScrewFast's name is `screwfast`, so the slug every rename starts from is
also the name of the template's fictional company, which its copy and its
demo content spell about five hundred times. The copy now reads the site's
name from one module (`apps/web/src/site.ts`): the copy tables, the data
files (turned into TypeScript modules for it), the constants, the logos'
labels, the web app manifest and the docs' title. The demo content under
`apps/web/src/content` — the products, posts, insights and docs, written as
that company — keeps its name: the rename engine masks it there, with the
template's repository and its name in the credits
(`tooling/rebrand/rebrand.mjs`, `UPSTREAM_CREDIT` and `THEME_WRITING`). And
because the slug is one word the template capitalises, the leftover sweep
looks for it in any case: `Screwfast`, `SCREWFAST` or a `screwfast_` file
name anywhere else fails it, as the slug, its Pascal form and its env prefix
do.

## What is here (the site)

| Surface | Where |
|---|---|
| The site's name (every page's title, the logos' labels, the footer, the Open Graph site name, the manifest, the docs' title, the copy that names the company) | `apps/web/src/site.ts` |
| The marketing copy, per language | `apps/web/src/copy/en.ts`, `apps/web/src/copy/fr.ts` |
| Features, pricing, FAQ, navigation and the site's constants | `apps/web/src/data_files/` (`fr/` for French) |
| Products, posts, insights (English and French) and the docs (seven languages) | `apps/web/src/content/` |
| Pages, views, layouts, components | `apps/web/src/pages`, `apps/web/src/views`, `apps/web/src/layouts`, `apps/web/src/components` |
| The docs' sidebar, languages, search and components | `starlight({…})` in `apps/web/astro.config.mjs`, `apps/web/src/components/ui/starlight` |
| The security headers | `apps/web/public/_headers` |
| The Worker in front of the assets (the 404 pages), its config, deploy contract | `apps/web/worker/index.ts`, `apps/web/wrangler.jsonc`, `apps/web/component.yaml` |
| Tests (the name seam, the origin, the Worker) | `apps/web/src/test` |

## Getting started

```bash
pnpm install
pnpm typecheck        # astro check
pnpm lint             # prettier --check (the template's format check)
pnpm test             # vitest over Astro's container API
pnpm build            # astro build (+ the docs' Pagefind index) and the minifier → apps/web/dist
```

```bash
pnpm --filter @app/web dev          # http://localhost:4321
pnpm --filter @app/web preview      # wrangler dev over the built site and its Worker
pnpm --filter @app/web test:smoke   # the template's own smoke over the build
```

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Static output (`dist/`) on Vercel's CDN | Workers Static Assets: `dist/` uploaded with the Worker `<repo>-web-<env>` (`apps/web/wrangler.jsonc`) |
| The template's build (`astro check && astro build && node process-html.mjs`) | Unchanged but for `astro check`, which runs as the `typecheck` step; `process-html.mjs` minifies `dist/` only (it also looked for `.vercel/output/static`) |
| `vercel.json` `headers` (CSP, frame options, HSTS …) | `public/_headers`, the same headers, which Workers Static Assets serve with every asset |
| `vercel.json` rewrite `/fr/:path*` → `/fr/404` | The Worker: a path under `/fr/` matching no file answers `/fr/404/` with a 404 (`apps/web/worker/index.ts`) |
| The host's 404 for any other unknown path | the Worker hands it to the assets, which answer `dist/404.html` with a 404 (`not_found_handling: 404-page`) |
| Directory URLs (`/products/`, the docs) | `assets.html_handling: auto-trailing-slash` — `/products/` serves `products/index.html`, `/products` redirects to it |
| `site: 'https://screwfast.uk'` | Each deploy builds for its own origin — the environment's `SITE_URL`, else its workers.dev URL — so canonical, hreflang and Open Graph links, the sitemap and robots.txt name the site where it is served; the domain placeholder is a local build's |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## CI

| Workflow | What it runs | Ships to a site |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a site carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the site built and dry-deployed per environment — they do not type-check, lint or run the tests; `baseline.yml`'s e2e tier runs those before each tag, and a site's README asks its developers to run them before a push), except the bootstrap's own landings (`orun/BASE-*`), which are checked in the box before they are pushed (`checks: local`) and whose PR runs `plan` alone; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does. A manual run (Orunbase's Deploy button, or Run workflow on `main`) plans the environment and components it names under the push-to-main trigger, so they deploy as a merge deploys them | yes |
| `baseline.yml` | the baseline's own tiers: contract tests, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, the site built, dry-deployed and served | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |

## Credits

The site is the ScrewFast template
([mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast)) by
Emil Gulamov (MIT — `apps/web/LICENSE`), at `86b25a9`.
