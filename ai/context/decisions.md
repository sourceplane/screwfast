# screwfast — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | The site builds fully static (`output: 'static'`, no adapter) and deploys as Workers Static Assets | ScrewFast is a static template (every page prerendered, its Vercel deploy a static output); an adapter would move prerendering into workerd for nothing | `specs/epics/screwfast/design.md` |
| 2 | One small Worker (`apps/web/worker/index.ts`) in front of the assets, which answers a path matching no file with the site's 404 page — the French one under `/fr/` | The template's Vercel config rewrote `/fr/*` to the French 404 page; Workers Static Assets serve the nearest `404.html`, and Astro writes the French page as `fr/404/index.html` | risk SF-B |
| 3 | The template's security headers (its `vercel.json`) are `public/_headers` | Workers Static Assets honour a `_headers` file; the headers stay the template's, verbatim | `apps/web/public/_headers` |
| 4 | Starlight's Pagefind index and the image optimisation stay build-time | Starlight indexes the built docs into `dist/pagefind`; sharp optimises every image (the demo's Unsplash photos downloaded) during `astro build`; the Worker needs neither | `apps/web/package.json` (`build`) |
| 5 | Astro held at 7.3.8 and `@astrojs/mdx` at 8.1.0 (a pnpm override, Starlight's copy too); the template's own dependency set otherwise | Astro 7.4 and MDX 8.1.1 need Node 22.23.4, and the Node 22 some GitHub runners carry is 22.23.3 | `pnpm-workspace.yaml`, IMPLEMENTATION-STATUS (departures) |
| 6 | The tests live in the app (`apps/web/src/test`), not a `tests/web` package | Astro components render only under Astro's own Vite config (the container API) | risk SF-D |
| 7 | One committed `wrangler.jsonc` is what deploys | There is no adapter to generate a second config; the lane checks the config exists before the build | `apps/web/component.yaml` |
| 8 | The site's name is one seam, `SITE_NAME` in `apps/web/src/site.ts`; the copy tables, the data files (now TypeScript modules), the constants, the logos' labels, the manifest and Starlight's title read it | The template spelled its name in about a hundred lines of copy; the rename rewrites one literal, and the copy names whatever the site is called | IMPLEMENTATION-STATUS (departures) |
| 9 | The demo content (`apps/web/src/content`: products, posts, insights, docs) keeps the template's company name, masked from the rename and the sweep; everywhere else the slug is swept in ANY case | The content is the template's writing as its fictional company, to be replaced; this baseline's one-word slug is that name, so `Screwfast`, `SCREWFAST` and a `screwfast_` file name must fail the sweep like the slug | `tooling/rebrand/rebrand.mjs` (UPSTREAM_CREDIT, THEME_WRITING, the any-case sweep), risk SF-G |
| 10 | `html_handling: auto-trailing-slash` | The template writes directory pages and links them with a trailing slash (`/products/`, the docs) | `apps/web/wrangler.jsonc` |
| 11 | Each deploy builds for its own origin: `PUBLIC_SITE_URL` = the environment's `SITE_URL`, else its workers.dev URL; the domain placeholder is a local build's | Canonical, hreflang and Open Graph links, the sitemap and robots.txt need an origin at build time, and each environment builds anyway (portfolio-starter-kit's shape) | risk SF-C |
| 12 | The social and home-page GitHub links and the docs' GitHub link point at the site's own repository; the contact address is on the site's domain | They are the site's, and the rename follows the source link and the domain to a site's own | `apps/web/src/data_files/navigation.ts`, `apps/web/astro.config.mjs` |
| 13 | `lint` is the template's own `prettier --check` (its CI's format check); the deploy contract and the generated component docs are left to their generator | The template has no ESLint; its formatter is its linter | `apps/web/package.json`, `apps/web/.prettierignore` |
| 14 | No custom-domain phase: a domain is the owner's step, and `SITE_URL` has the record probe it | The brokered `workers-deploy` token has no zone scope | README, "Custom domain" |
| 15 | One landing (`01-product`) then the record (`03-docs`), each checked in the build box | A landing has a fixed cost; the convergence on main builds, deploys and smoke-tests the site for real | `docs/phases/README.md` |
| 16 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME`; no Checks workflow | A bootstrap cannot set a repository variable; a push to main must start `ci.yml` alone | `.github/workflows/ci.yml` |
| 17 | stack-tectonic 0.19.0, not 0.20.0 | The job installs in its own tree; 0.20.0's lane-shared install broke the Next.js siblings live and would save nothing here | risk SF-F |
| 18 | orun is pinned only where it runs (the `orun-action` `version:` in each workflow); no kiox | A pin nothing runs drifts | `.github/workflows/` |
| 19 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the component's facts drifts silently | `tooling/catalog/gen-component-docs.py` |
| 20 | `subdomain` is read from the Cloudflare connection, never asked; the console asks for no domain | Both belong to the account or the owner, not to the build | `blueprint.yaml` |
