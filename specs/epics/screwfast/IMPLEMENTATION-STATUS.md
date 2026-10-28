# screwfast — implementation status

| Milestone | State | Landed |
|---|---|---|
| SF0 — the spec | ✅ | the repository's first commit |
| SF1 — the site on Workers | ✅ | SF-2 |
| SF2 — a baseline | ✅ | SF-3, tagged `baseline-v1` |

## Departures from the upstream template

Everything not listed here is the template as it is upstream at `86b25a9`.

| # | What | Why |
|---|---|---|
| 1 | The app lives in `apps/web` of a pnpm workspace; `vercel.json`, `AI_GUIDE.md`, `CONTEXT.md`, `CODE_OF_CONDUCT.md`, `.github/` (its CI and Dependabot workflows), `.vscode/` and `pnpm-lock.yaml` are not carried; the template's README is this repository's credit | Another host's and the upstream project's own files; the workspace has one `.vscode` and one lockfile |
| 2 | `wrangler.jsonc` names the Worker `<repo>-web`, with `main: ./worker/index.ts`, the `ASSETS` binding over `dist/`, `html_handling: auto-trailing-slash` and `not_found_handling: 404-page` | The composition deploys a Worker with its assets |
| 3 | `apps/web/worker/index.ts` answers a path under `/fr/` matching no file with `/fr/404/` and a 404 | `vercel.json`'s `/fr/:path*` → `/fr/404` rewrite |
| 4 | `public/_headers` carries `vercel.json`'s headers, verbatim | Workers Static Assets' form of them |
| 5 | `src/site.ts` (`SITE_NAME`) is the site's name. The copy tables' strings that named the company are template literals over it; `features`, `pricing` and `faqs` (both languages) are TypeScript modules instead of JSON, doing the same; `SITE.title` in `constants.ts`, the manifest's names, the logos' `aria-label`s and Starlight's title (`` `${SITE_NAME} Docs` ``) read it; the copy was reformatted by the template's own Prettier where the literals changed | One rename seam; the template named itself in about a hundred lines of code |
| 6 | The template's Starlight logo and hero files are `logo.svg`, `logo_dark.svg`, `hero.svg`, `hero_dark.svg` (were `screwfast_*.svg`), and the docs pages that show them follow | A file name spelling the slug is residue to the leftover sweep |
| 7 | `astro.config.mjs`'s `site` is `PUBLIC_SITE_URL` when a deploy sets it, else `https://screwfast.example.com` (the domain placeholder); `SITE.url` is Astro's `site` (`import.meta.env.SITE`), so canonical and hreflang links follow; Starlight's `og:image` meta is built on the same origin | Upstream's own origin (`screwfast.uk`) is not a product's; each deploy names its own |
| 8 | The social GitHub link, the home page's two GitHub links and the docs' GitHub link are `https://github.com/sourceplane/screwfast` (renamed with the site); the contact address is `support@screwfast.example.com` (the domain placeholder); the Twitter domain fallback is the placeholder | Upstream's point at the template's repository and domain, not the site's |
| 9 | `build` is `astro build && node process-html.mjs` — upstream's without `astro check`, which is the workspace's `typecheck`; `process-html.mjs` minifies `dist/` only (it also looked for Vercel's adapter output) | The workspace's `typecheck` / `lint` / `test` / `build` contract |
| 10 | `typecheck` is `astro check` (`vitest.config.ts` and `.wrangler` excluded from it), `lint` is the template's own `prettier --check .` (its CI's format check; `component.yaml` and the generated `docs/` left to their generator) | The workspace's contract; the template has no ESLint |
| 11 | `scripts/smoke.mjs` (`test:smoke`) checks the hreflang links on the origin the build was made for, not `screwfast.uk` | Each build names its own origin |
| 12 | Tests: `src/test/site.test.ts` (the seam, rendered under another name), `src/test/origin.test.ts`, `src/test/worker.test.ts` (vitest over Astro's container API); `vitest`, `wrangler` and `@types/node` are dev dependencies | The template ships only its smoke script |
| 13 | `astro` is held at `7.3.8` and `@astrojs/mdx` at `8.1.0` (upstream `^7.4.2` and `^8.1.1`), by a pnpm override so Starlight's copy is held too | Astro 7.4 and MDX 8.1.1 need Node 22.23.4; the lanes and Baseline CI run `node-version: 22`, which some GitHub runners resolve to 22.23.3 |
| 14 | `.astro/` is ignored by git, the blueprint and the leak gate | What `astro check` and the build generate is a build's, not the site's |
| 15 | `pnpm-workspace.yaml`'s `onlyBuiltDependencies` (esbuild, workerd, sharp) | pnpm 10 runs no dependency build script unless allow-listed |
