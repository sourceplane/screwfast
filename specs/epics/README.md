# Epics

Orun-style work programs. Each epic is a folder carrying `epic.yaml` (the
declaration the platform reads: slug, key prefix, milestones with exit
criteria and task keys) beside its doc set. The pull request that adds the
folder is the adoption; the merge creates the epic in the workspace.

| Epic | Cluster | Status | What it is |
|------|---------|--------|------------|
| [`screwfast/`](./screwfast/) | **SF** | In progress (SF1: the site on Workers) | Vercel's ScrewFast template — an Astro marketing site in English and French with Starlight docs in seven languages — built static and served as Cloudflare Workers Static Assets behind one Worker, and an Orun baseline that instantiates it (SF2) |

As-built ≠ intent: what shipped lives in each epic's `IMPLEMENTATION-STATUS.md`.
