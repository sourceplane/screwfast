# apps/web — the site

A marketing site and its documentation on the ScrewFast template
([mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast), MIT) —
Astro 7, Tailwind CSS 4, Preline UI and Starlight — built fully static and
served as Cloudflare Workers Static Assets:

- the marketing pages, in English (`/`) and French (`/fr/`): the home page,
  `/products/` and a page per product, `/services/`, `/contact/`, `/blog/`
  and its posts, and the customer insights (`/insights/<id>/`)
- the docs (Starlight), in English at the root (`/welcome-to-docs/`,
  `/guides/…`, `/tools/…`, `/construction/…`, `/advanced/…`) and under
  `/de/`, `/es/`, `/fa/`, `/fr/`, `/ja/` and `/zh-cn/`, with their Pagefind
  search index under `/pagefind/`
- `/manifest.json`, `/favicon.ico`, `/sitemap-index.xml`, `/robots.txt`, and
  the 404 pages (`/404`, and the French one for anything under `/fr/`)

The site's name — every page's title, the logos' labels, the footer, the
Open Graph site name, the manifest, the docs' title and the copy that names
the company — is `src/site.ts`. The words around it are `src/copy/en.ts`
and `src/copy/fr.ts`; features, pricing and the FAQ are
`src/data_files/` (`fr/` for French); the products, posts, insights and docs
are `src/content/`. The docs' sidebar and languages are `starlight({…})` in
`astro.config.mjs`. The demo content is the template's, written as its
fictional company: replace it.

```bash
pnpm dev          # http://localhost:4321
pnpm build        # astro build + the minifier → dist/
pnpm preview      # wrangler dev over dist/ and the Worker
pnpm test         # vitest
pnpm test:smoke   # the template's own route checks over dist/
pnpm typecheck    # astro check
pnpm lint         # prettier --check
```

`worker/index.ts` answers what matches no file in `dist/` with the site's
404 page (the French one under `/fr/`); `public/_headers` carries the
template's security headers; `wrangler.jsonc` and `component.yaml` are the
Worker's config and the deploy contract.
