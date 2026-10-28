# screwfast — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a site built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's ScrewFast template (mearashadowfax/ScrewFast) — an Astro, Tailwind
CSS and Preline UI marketing site for a fictional hardware and construction
company: home, products, services, pricing, FAQ, contact, a blog and
customer insights, in English and French, with a Starlight documentation
section in seven languages and its Pagefind search — built fully static and
served as Cloudflare Workers Static Assets behind one small Worker, packaged
as an Orun baseline: `orun new --blueprint repo-blueprint.yaml` builds a new
site in its own repository and takes it to live on stage and prod in one
landing (`01-product`), then records what went live (`03-docs`).

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` — SF0 to SF2: the repository, the site on Workers, and the baseline (blueprint, phases, tests) |
| Proven live | Not yet: proven offline in Baseline CI only (risk SF-A) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/screwfast/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/screwfast/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/screwfast/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What the component is | `apps/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one site from `baseline-v1` from the console and record its
   timings against the 5-minute estimate (closes SF-A); then the registry
   row goes public with the measured minutes.
