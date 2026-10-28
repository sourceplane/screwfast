# screwfast — Vercel's ScrewFast template on Cloudflare Workers

**ScrewFast builds fully static — its docs, their search index and every
optimised image included — so the port is where it is served: `dist/` as
Cloudflare Workers Static Assets behind one small Worker (the French 404
page under `/fr/`), deployed by Orun to stage and prod on every merge, with
the site's name moved into one seam the copy reads — and the baseline that
makes a copy of it somebody else's site in one landing.**

| | |
|---|---|
| Status | In progress — SF1 on main: the site runs on Workers |
| Upstream | [mearashadowfax/ScrewFast](https://github.com/mearashadowfax/ScrewFast) (MIT), at `86b25a9` (2026-10-27; the repository has no release tags) |
| Reference | [astro-boilerplate](https://github.com/sourceplane/astro-boilerplate) — the same scaffolding, tests and bootstrap; [astro-paper](https://github.com/sourceplane/astro-paper) and [astrowind](https://github.com/sourceplane/astrowind) — the same static build behind one Worker |
| Key | `SF` |

## Read in this order

1. [design.md](design.md) — the template, how each Vercel piece maps to
   Cloudflare, the repository and the build, and the alternative rejected.
2. [implementation-plan.md](implementation-plan.md) — the milestones and
   what each one lands.
3. [risks-and-open-questions.md](risks-and-open-questions.md) — what is not
   proven, and what was accepted.
4. [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) — what shipped, and
   every departure from the upstream template.

## Milestones

| Milestone | What it lands | Task |
|---|---|---|
| SF0 — the spec | the repository, its intent, CI, tooling and spec index; this doc set | SF-1 |
| SF1 — the site on Workers | the template in `apps/web`, built static with its docs and their index, served as assets behind one Worker, its name one seam | SF-2 |
| SF2 — a baseline | the console card, the build document, the context pack and the baseline's tests | SF-3 |
