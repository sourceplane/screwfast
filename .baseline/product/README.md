# screwfast

A marketing site and its documentation, on the ScrewFast template
([mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast)) —
Astro, Tailwind CSS and Preline UI: a home page with features, pricing, FAQ
and testimonials, products and a page per product, services, contact, a blog
and customer insights, in English and French, and a Starlight documentation
section in seven languages (English, German, Spanish, Farsi, French,
Japanese and Simplified Chinese) with its full-text search — built fully
static and served from **Cloudflare Workers + Static Assets**.

## Live deployment

<!-- 03-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the site uses into
[ai/context/deployment.md](ai/context/deployment.md); how the site deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 03-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The site's name (every page's title, the logos' labels, the footer, the Open Graph site name, the web app manifest, the docs' title, the copy that names the company) | `apps/web/src/site.ts` |
| The marketing copy, per language: titles, descriptions, the home page's sections, services, contact, the navigation | `apps/web/src/copy/en.ts`, `apps/web/src/copy/fr.ts` |
| Features, pricing and the FAQ, per language | `apps/web/src/data_files/` (`fr/` for French) |
| Products, blog posts, insights (English and French) and the docs (seven languages) | `apps/web/src/content/{products,blog,insights,docs}` |
| Pages (a file per route; `fr/` for French), views, layouts and components | `apps/web/src/pages`, `apps/web/src/views`, `apps/web/src/layouts`, `apps/web/src/components` |
| The docs' sidebar, languages and search | `starlight({…})` in `apps/web/astro.config.mjs` |
| Colours and typography | `apps/web/src/assets/styles` |
| The security headers | `apps/web/public/_headers` |
| The Worker in front of the assets (the 404 pages), its config and deploy contract | `apps/web/worker/index.ts`, `apps/web/wrangler.jsonc`, `apps/web/component.yaml` |
| Tests (the name seam, the origin, the Worker) | `apps/web/src/test` |

## Getting started

```bash
pnpm install
pnpm typecheck        # astro check
pnpm lint             # prettier --check
pnpm test             # vitest over Astro's container API
pnpm build            # astro build (+ the docs' Pagefind index) and the HTML minifier → apps/web/dist
```

```bash
pnpm --filter @app/web dev          # http://localhost:4321
pnpm --filter @app/web preview      # wrangler dev over the built site and its Worker
pnpm --filter @app/web test:smoke   # the routes the template's own smoke reads, over the build
```

Make the site yours: its name in `apps/web/src/site.ts`; the words around
it in `apps/web/src/copy/` and `apps/web/src/data_files/`; its products,
posts, insights and docs in `apps/web/src/content/`. The content it was born
with is the template's demo, written as its fictional hardware and
construction company — the posts, insights, product pages and docs still say
that company's name until you replace them; the pages' chrome and copy say
yours. A binding the Worker needs (KV, R2, D1, a variable) goes in
`apps/web/wrangler.jsonc`.

The site is static: every page and the docs' search index are files in
`dist/` at build time, and the Worker (`apps/web/worker/index.ts`) only
answers requests that match no file, with the site's own 404 page — the
French one under `/fr/`. A redirect, a header or an API route the site needs
later goes in that Worker. The contact form is the template's demo: it
submits nowhere.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The site deploys to `stage`, then to
`prod` once stage has converged on the same commit; `dev` only verifies. The
Worker is `screwfast-web-<env>` on your account's workers.dev subdomain, and
every deploy is smoke-tested over HTTP. A pull request runs the same
pipeline's verify lanes: the site built and dry-deployed for each
environment, with nothing deployed. They do not type-check, lint or run the
tests, so run `pnpm typecheck`, `pnpm lint` and `pnpm test` before you push.
(A push to `main` builds, deploys and smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; nothing provider-shaped is stored in the repository
or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after rotating a
secret, say. A component with nothing to run in that environment (a test
suite in `prod`) is left out with a notice.

## Custom domain

The site answers on workers.dev from its first deploy. To serve it on your
own domain:

1. Add the domain to the Cloudflare account the site deploys into, and attach
   it to the Worker (dashboard → Workers & Pages →
   `screwfast-web-prod` → Settings → Domains & Routes → Add →
   Custom domain). Do the same for stage with a subdomain if you want one.
2. Record the environment's public origin in `intent.yaml`: the deploy
   builds the site's canonical, hreflang and Open Graph links, sitemap and
   robots.txt for it (until then they name the workers.dev URL), and the
   deployment record probes it beside the workers.dev URL:

   ```yaml
   environments:
     prod:
       env:
         SITE_URL: https://screwfast.example.com
   ```

   The site was born with the reserved placeholder `screwfast.example.com`
   where its domain goes: that example, `BASE_DOMAIN` under each environment
   (dev, stage and prod) in `intent.yaml`, the origin a local build uses in
   `apps/web/astro.config.mjs`, and the contact address in
   `apps/web/src/components/sections/misc/ContactSection.astro`. Replace it
   with your domain in the same change, and land it with a change under
   `apps/web` so the merge rebuilds the site.

## Credits

The site is the ScrewFast template
([mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast)),
© Emil Gulamov, MIT-licensed (`apps/web/LICENSE`). Its demo content — the
products, posts, insights and docs — and its logo describe the template's
fictional company; replace them with your own as you make the site yours.
