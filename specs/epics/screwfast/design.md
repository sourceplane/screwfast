# screwfast — design

## The template

[ScrewFast](https://github.com/mearashadowfax/ScrewFast) is an Astro 7,
Tailwind CSS 4 and Preline UI marketing site for a fictional hardware and
construction company: a home page (hero, clients, features, pricing, FAQ,
testimonials, statistics), products with a page per product, services,
contact with a demo form, a blog and customer insights, with GSAP and Lenis
animation and light and dark mode. The marketing pages exist in English
(`/`) and French (`/fr/`): their words are typed copy tables
(`src/copy/en.ts`, `fr.ts` — a key missing from French fails `astro check`),
their data per-language files (`src/data_files/`), and a middleware resolves
the locale per page. Beside them is a Starlight documentation section in
seven languages (English, German, Spanish, Farsi right to left, French,
Japanese, Simplified Chinese) with Starlight's Pagefind search, the
template's own Starlight components (its site title, head, theme switch) and
the site's 404 page in place of Starlight's.

It is `output: 'static'`: every route is a file at build time, the demo's
Unsplash photos are downloaded and optimised with the rest, and the build
minifies the pages afterwards (`astro check && astro build && node
process-html.mjs`). On Vercel, `vercel.json` adds security headers and
rewrites unknown French paths to the French 404 page.

## How it maps to Cloudflare

| Vercel | Here | Why |
|---|---|---|
| Static output on Vercel's CDN | `dist/` as Workers Static Assets, uploaded with `<repo>-web-<env>` | The template is static; the assets are the site |
| `vercel.json` headers | `public/_headers`, the same headers | Workers Static Assets serve a `_headers` file's rules with every asset |
| `vercel.json` rewrite `/fr/:path*` → `/fr/404` | One Worker, `apps/web/worker/index.ts`: a path under `/fr/` matching no file answers `/fr/404/` with a 404 | The assets serve the nearest `404.html`, and Astro writes the French 404 page as `fr/404/index.html`; the composition deploys a Worker with its assets anyway |
| The host's 404 | `not_found_handling: 404-page` → `dist/404.html` with a 404 | The template's own 404 page (Starlight's is disabled) |
| Directory pages linked with a trailing slash | `assets.html_handling: auto-trailing-slash` | Astro writes `<path>/index.html`; `/products` redirects to `/products/` |
| Starlight's Pagefind step | Unchanged: Starlight indexes the built docs into `dist/pagefind`, served as assets | Search is client-side over a static index |
| `site: 'https://screwfast.uk'` | `PUBLIC_SITE_URL` per deploy: the environment's `SITE_URL`, else its workers.dev URL; `<repo>.example.com` for a local build | Canonical, hreflang and Open Graph links, the sitemap and robots.txt need an origin at build |

## The repository

The same as astro-boilerplate's, with astro-paper's static build: `apps/web`
is the only component (type `cloudflare-workers-assets-turbo`, lane
`isolated`, deployed on stage and prod on a push to `main`, verified on dev
and on pull requests), its tests live in the app because Astro components
render only under Astro's Vite config, and there is no infrastructure: no
database, no bucket, no runtime secret.

## The name

This baseline's slug is the template's own name, and the template is a
company's site: the name is in its constants, its copy tables in both
languages (titles, descriptions, the hero, the services, the testimonials),
its features, pricing and FAQ data, its logos' labels, its web app manifest,
Starlight's title, and throughout its demo content. So the site's name moves
into one seam, `SITE_NAME` in `src/site.ts`, and every place in the code that
named the company reads it: the copy tables' strings become template
literals over it, the data files that named it become TypeScript modules
doing the same, the constants' title is it, Starlight's title is
`` `${SITE_NAME} Docs` ``. A site named something else says that name on
every page's chrome and in all its copy — and `src/test/site.test.ts` holds
it there, rendering with a different name.

The demo content under `src/content` — the products, posts, insights and
docs — is the template's writing as that company, and keeps its name: it is
masked from the rename and allowed in the leftover sweep, there only and in
the template's spelling only, with the template's repository and its name in
the credits. Because the slug is one word that the template writes
`ScrewFast`, the sweep looks for it in any case: `Screwfast`, `SCREWFAST` or
a `screwfast_` file name (the template's Starlight logo files, renamed) fails
it anywhere else, as the slug, its Pascal form and its env prefix do.

## The build

`repo-blueprint.yaml` is astro-boilerplate's: one landing (`01-product`)
places, brands and lands the whole tree, one convergence builds and deploys
stage and prod side by side, and `03-docs` records what went live. The
smoke checks that the home page links its French version, that
`/products/` lists the first product, that the docs' welcome page and their
search index are served, and that unknown paths are 404s — the French page
under `/fr/`.

## Out of scope

- The contact form: the template's is a demo that submits nowhere, as
  upstream.
- The demo content: it stays the template's until a site replaces it.

## The alternative rejected

**Astro's Cloudflare adapter**, as astro-boilerplate uses. It would move the
build's prerendering — 109 pages in seven languages and their images — into
workerd through the Cloudflare Vite plugin, emit a server entry nothing
calls and generate a second wrangler config, for a site with no on-demand
route. A static build with a Worker in front of it is what the template is;
the Worker earns its place with the French 404 page.
