# screwfast — implementation plan

Three milestones, each one reviewed pull request (SF0 is the repository's
first commit), each green before it merges.

## SF0 — the spec (SF-1)

The repository is born: `intent.yaml` with the placeholder workspace
`ws_CHANGE_ME`, `ci.yml` (byte for byte turso-starter's, which plans nothing
until the workspace is set), the shared TypeScript and ESLint configuration,
the spec index, this doc set and the task contracts.

## SF1 — the site on Workers (SF-2)

- The template's `src/`, `public/`, `astro.config.mjs`, `process-html.mjs`,
  its smoke script and its Prettier configuration in `apps/web`, its
  dependencies in `apps/web/package.json`; Astro and MDX held where the
  runners' Node 22 can run them.
- `worker/index.ts` and `wrangler.jsonc`: the Worker in front of `dist/`,
  directory URLs, both 404 pages; `public/_headers`, the template's headers.
- The site's name in `src/site.ts`, read by the copy, the data, the
  constants, the logos, the manifest and Starlight; the origin from
  `PUBLIC_SITE_URL` through Astro's `site`; the GitHub links to the site's
  own repository and the contact address on its domain.
- `component.yaml`: the deploy contract and its smoke.
- Tests (`src/test`): the name seam (another name, rendered), the origin,
  the Worker.
- The README's "How it maps to Vercel".

## SF2 — a baseline (SF-3)

astro-boilerplate's machinery, renamed: `blueprint.yaml`,
`repo-blueprint.yaml`, `.baseline/` (identity, product README, task
contracts), `tooling/rebrand` (the template's credit and demo content
masked; the slug swept in any case), `tooling/bootstrap`,
`hooks/render-deployment-docs.sh` (probing `/`, `/products/` and the docs),
`docs/phases/`, the context pack, `testing/` (the leak and placement gates
on this tree's files; the e2e tier reading every route the site promises)
and `baseline.yml` / `tag.yml`.
