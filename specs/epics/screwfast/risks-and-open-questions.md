# screwfast — risks and open questions

| ID | Risk | State | Notes |
|---|---|---|---|
| SF-A | `baseline-v1` is not yet proven live | OPEN | Proven offline in Baseline CI: the offline bootstrap with the blueprint's own hooks, the stage lane's own steps in a staged job tree, the site served by `wrangler dev` and smoke-tested with the component's own command. A console bootstrap closes it |
| SF-B | A Worker in front of a static site | ACCEPTED | The composition deploys a Worker with its assets; this one answers only what no file matches, with the site's 404 page — the French one under `/fr/`, as the template's Vercel rewrite did. A request that matches a file never reaches it |
| SF-C | Absolute links are built in, per environment | ACCEPTED | Canonical, hreflang and Open Graph links, the sitemap and robots.txt carry the origin the deploy built for: the environment's `SITE_URL` (a custom domain), else its workers.dev URL. Attaching a domain is setting `SITE_URL` and merging |
| SF-D | The tests live in the app | ACCEPTED | Astro components render only under Astro's Vite config (the container API); a `tests/web` package would need it anyway |
| SF-E | The build downloads the demo's Unsplash photos | ACCEPTED | Astro's image service fetches the remote avatars and product shots at build time and optimises them, as upstream; every lane has the network. Replacing them with local images removes it |
| SF-F | stack-tectonic 0.19.0, not 0.20.0 | ACCEPTED | 0.20.0's lane-shared install links each job's `node_modules` out of its tree; the siblings pin 0.19.0 for it and the site would save nothing |
| SF-G | The slug is the template's own name | RESOLVED | The code reads the site's name from one seam; the demo content keeps the template's company name, masked there only, with the template's repository and its name in the credits. The slug is swept in any case, so any other spelling anywhere else fails. `testing/rebrand.test.sh` holds both sides, `apps/web/src/test/site.test.ts` the seam |
| SF-H | The demo content names the template's company | ACCEPTED | A site's chrome and copy say its own name from its first build; its products, posts, insights and docs say the template's until the owner replaces them (README, "Make the site yours") |
