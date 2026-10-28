# screwfast

Vercel's [ScrewFast](https://github.com/mearashadowfax/ScrewFast) template —
an Astro, Tailwind CSS and Preline UI marketing site for a hardware and
construction company: a home page with features, pricing, FAQ and
testimonials, products and a page per product, services, contact, a blog and
customer insights, in English and French, and a Starlight documentation
section in seven languages with its full-text search — running on
**Cloudflare Workers + Static Assets**, deployed by
[Orun](https://github.com/sourceplane/orun) to stage and prod on every merge.
Packaging it as an Orun baseline is the next milestone (SF2).

ScrewFast builds fully static: `astro build` writes every marketing page,
product, post, insight and docs page to `dist/`, optimising every image with
sharp, Starlight's Pagefind indexes the docs into `dist/pagefind`, and the
template's minifier rewrites the pages in place. That folder is uploaded as
Workers Static Assets with one small Worker in front for what matches no
file — the site's 404 page, the French one under `/fr/`, as the template's
Vercel rewrite served it; no adapter and no server code. The pages, the
copy, the languages and the docs do not change; the site's name moves into
one module that the copy reads, and each deploy builds for its own origin.
See [`specs/epics/screwfast`](specs/epics/screwfast/README.md) for the
design, the milestones and the as-built status.

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

## Credits

The site is the ScrewFast template
([mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast)) by
Emil Gulamov (MIT — `apps/web/LICENSE`), at `86b25a9`.
