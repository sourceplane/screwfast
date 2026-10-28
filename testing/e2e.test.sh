#!/usr/bin/env bash
# TIER 2 — the site a bootstrap produces builds, deploys (dry) and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the finished site, the landing's own checks — install with the
#      lockfile the site ships, render fixtures, typecheck, lint, test,
#      build. The bootstrap's own landings are checked in the box with
#      `orun validate` and `orun plan` alone (`checks: local`; their PR's CI
#      on an `orun/BASE-…` branch is `plan` alone, and the convergence on
#      main builds, deploys and smoke-tests the site), and a later pull
#      request of the site runs ci.yml's verify lanes, which build and
#      dry-deploy it — so THIS is where the site's type-check, lint and tests
#      run before it ships: before the tag, not after a build has merged it;
#   2. the stage lane's own steps, rendered by `orun plan` in the site: on a
#      pull request (the verify profile) `verify-app-structure` (the deploy
#      config must exist BEFORE the build), `build-app` — the component's
#      buildCommand, the same step the deploy profile runs —
#      `verify-build-output` and `deploy-dry-run` (`wrangler deploy --dry-run
#      --config <wranglerConfig> --name <reponame>-web-stage`). They run IN THE
#      TREE THE RUNNER STAGES for the job (testing/lib/stage-job.py), with the
#      dependency layout the pinned composition produces: if its install step
#      is `scope: lane`, the top-level node_modules is a symlink to the source
#      checkout's; if not, the job's own install step runs inside the staged
#      tree. A staged tree has no dist/, which is what makes the structure
#      and output checks honest: the config the lane deploys is committed, the
#      Worker entry is a source file, and dist/ is what the build just wrote;
#   3. serve the built Worker with `wrangler dev` over the component's own
#      wranglerConfig and run the component's OWN `smokeCommand` against it,
#      verbatim — the check the real deploy ends with — and then read every
#      route the site promises: the home page, its header logo, footer and
#      every page's title carry the site's name, and none of its marketing
#      pages still says the template's; the marketing pages in English and
#      French (products and a product, services, contact and its demo form,
#      the blog and a post, an insight) with their hreflang alternates and
#      canonical links on the stage origin; the docs in each of their seven
#      languages (Farsi right-to-left) under "<name> Docs", and the Pagefind
#      index their search loads; the web app manifest, the sitemap and
#      robots.txt; the template's security headers; a page without its
#      trailing slash redirected to it; and an unknown path the site's own
#      404 page with a 404 status — the French one under /fr/.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev. That is a
# bootstrap against a workspace (BOOTSTRAP.md); everything short of it is here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` (or a warm store). A few minutes: two installs and builds
# (the landing's checks over the site, and the stage lane's own in its staged
# tree).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false ASTRO_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step, run here at once on the whole
# tree. A pull request in the site builds and dry-deploys it through ci.yml's
# lanes; the type-check, the lint and the tests run here, and by hand before
# a push.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"

# ── 1. the finished site ───────────────────────────────────────────────────
echo "── the finished site: install, the fixture render, typecheck, lint, test, build"
checks "$tree" "$scratch/checks-site.log"

# ── 2. the deploy lane's steps, for stage ──────────────────────────────────
echo "── the stage lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
# The 01-product landing over the repository's empty first commit: every file
# of the site changed, as on its pull request.
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
python3 - "$scratch/plan.json" "$scratch/steps" <<'PY'
import json, pathlib, sys
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
for s in job["steps"]:
    if s["id"] in ("verify-app-structure", "build-app", "verify-build-output", "deploy-dry-run"):
        (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    if s["id"] == "install-workspace-dependencies":
        (out / "install.sh").write_text(s.get("run") or "")
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or "apps/web")
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
PY
# The job's private tree, staged as orun stages it. The source checkout
# carries no build output (a CI checkout has none, so the plain-tree build's is
# removed rather than copied in), and its dependencies are what the pinned
# composition says: a lane-scoped install ran once in the source tree (step 1
# ran the same command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/dist" "$tree/apps/web/.wrangler"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
[ -f "$scratch/steps/install.sh" ] || { echo "FAIL: the stage lane has no install step" >&2; exit 1; }
if [ "$(cat "$scratch/steps/install.scope")" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
  echo "   ▸ install-workspace-dependencies"
  (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/install.wd")" && bash -e "$scratch/steps/install.sh") \
    > "$scratch/install.log" 2>&1 || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install.log" >&2; exit 1; }
  [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
    || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
fi
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  [ -f "$scratch/steps/$step.sh" ] || { echo "FAIL: the stage verify lane has no $step step" >&2; exit 1; }
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the deploy lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done

# What the deploy would upload: the Worker bundled from its source entry, and
# the static build beside it as assets.
grep -q 'Total Upload' "$scratch/deploy-dry-run.log" || { echo "FAIL: the dry run listed no Worker upload" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
cfg="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['wranglerConfig'])" "$tree/apps/web/component.yaml")"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the built Worker ($cfg)"
port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config "$cfg" --ip 127.0.0.1 --port "$port" \
   --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 90); do
  curl -s -o /dev/null "$url/" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

echo "   ▸ the component's own smokeCommand, DEPLOYED_URL=$url"
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the site" >&2; exit 1; }

echo "   ▸ every route the site promises"
python3 - "$url" "$values" <<'PY'
import html, json, re, sys, urllib.error, urllib.parse, urllib.request
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name, repo = values["productname"], values["reponame"]
# The origin the stage lane built for: its workers.dev URL (no SITE_URL set).
origin = f"https://{repo}-web-stage.{values['subdomain']}.workers.dev"
problems = []
def bad(m): problems.append(m)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
opener = urllib.request.build_opener(NoRedirect)
def get(path):
    try:
        with opener.open(urllib.parse.urljoin(base + "/", path), timeout=30) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None

def labels(fragment):
    return [html.unescape(v) for v in re.findall(r'aria-label="([^"]*)"', fragment)]
def text_of(fragment):
    return html.unescape(re.sub(r"<[^>]+>", " ", fragment))

# / — the template's home page, under the site's name.
status, headers, body = get("/")
page = body.decode()
if status != 200 or '<html lang="en"' not in page:
    bad(f"/ answered {status} without lang=en")
if title(page) != name:
    bad(f"the home page's <title> is {title(page)!r}, not {name!r}")
header = re.search(r"<header.*?</header>", page, re.S)
if not header or name not in labels(header.group(0)):
    bad(f"the header's logo is not labelled {name!r}")
footer = re.search(r"<footer.*?</footer>", page, re.S)
if not footer or name not in text_of(footer.group(0)):
    bad(f"the footer does not say {name!r}")
if f'<link rel="canonical" href="{origin}">' not in page:
    bad(f"the home page's canonical link is not {origin}, the origin the stage lane built for")
if f'hreflang="fr" href="{origin}/fr"' not in page:
    bad("the home page does not link its French version on the stage origin")
site_name = re.search(r'<meta property="og:site_name" content="([^"]*)"', page)
if not site_name or html.unescape(site_name.group(1)) != name:
    bad(f"the home page's og:site_name is {site_name and html.unescape(site_name.group(1))!r}, not {name!r}")
# The copy names the company by the site's name (the hero, the features…).
if text_of(page).count(name) < 5:
    bad(f"the home page's copy names {name!r} only {text_of(page).count(name)} time(s)")

# The marketing pages, in English and French, under "<page> | <name>" —
# and none of them, nor the chrome around them, still says the template's
# name (the demo posts and insights do: they are its writing).
pages = (("/products/", "Products"), ("/services/", "Services"), ("/contact/", "Contact"), ("/blog/", "Blog"),
         ("/fr/products/", "Produits"), ("/fr/services/", "Services"), ("/fr/contact/", "Nous Contacter"),
         ("/fr/blog/", "Blog"))
for path, heading in (("/", None), ("/fr/", None)) + pages:
    s, h, b = get(path)
    page = b.decode()
    t = title(page)
    if heading and (s != 200 or t != f"{heading} | {name}"):
        bad(f"{path} answered {s} titled {t!r}, not '{heading} | {name}'")
    if path.startswith("/fr/") and '<html lang="fr"' not in page:
        bad(f"{path} is not in French (lang=fr)")
    if path in ("/", "/fr/", "/services/", "/fr/services/", "/contact/", "/fr/contact/") and "ScrewFast" in page:
        bad(f"{path} still says 'ScrewFast'")
for path, needle in (("/products/", "/products/item-a765/"), ("/contact/", "data-demo-form"),
                     ("/fr/contact/", "data-demo-form"), ("/blog/", "/blog/post-1/")):
    s, h, b = get(path)
    if needle not in b.decode():
        bad(f"{path} has no {needle}")
for path, needle in (("/products/item-a765/", None), ("/blog/post-1/", '"@type":"BlogPosting"'),
                     ("/fr/blog/post-1/", '"inLanguage":"fr"'), ("/insights/insight-1/", None),
                     ("/fr/insights/insight-1/", None), ("/fr/products/item-a765/", None)):
    s, h, b = get(path)
    page = b.decode()
    if s != 200 or not (title(page) or "").endswith(f" | {name}") or (needle and needle not in page):
        bad(f"{path} answered {s} titled {title(page)!r}" + (f" without {needle}" if needle else ""))
s, h, b = get("/products/")
if f'<link rel="canonical" href="{origin}/products/">' not in b.decode():
    bad(f"/products/'s canonical link is not on {origin}")

# The docs (Starlight): every language, "<page> | <name> Docs", Farsi right
# to left, the docs logo labelled with the site's name, and the search index.
for lang, prefix in (("en", ""), ("de", "/de"), ("es", "/es"), ("fa", "/fa"), ("fr", "/fr"),
                     ("ja", "/ja"), ("zh-CN", "/zh-cn")):
    s, h, b = get(f"{prefix}/guides/intro/")
    page = b.decode()
    if s != 200 or f'lang="{lang}"' not in page:
        bad(f"{prefix}/guides/intro/ answered {s} without lang={lang}")
    if not (title(page) or "").endswith(f" | {name} Docs"):
        bad(f"{prefix}/guides/intro/ is titled {title(page)!r}, not '… | {name} Docs'")
    if lang == "fa" and 'dir="rtl"' not in page:
        bad("the Farsi docs are not right to left")
s, h, b = get("/welcome-to-docs/")
page = b.decode()
if s != 200 or name not in labels(page) or f"{name} Docs" not in labels(page):
    bad(f"/welcome-to-docs/ answered {s} without the logos labelled {name!r} and '{name} Docs'")
if "pagefind" not in page:
    bad("the docs do not load Pagefind's search")
for path in ("/pagefind/pagefind.js", "/pagefind/pagefind-ui.js", "/pagefind/pagefind-entry.json"):
    s, _, _ = get(path)
    if s != 200:
        bad(f"{path} answered {s} — the docs' search index is not deployed")

# The web app manifest, and the crawlers' files, on the stage origin.
s, h, b = get("/manifest.json")
try:
    manifest = json.loads(b)
except ValueError:
    manifest = {}
if s != 200 or manifest.get("name") != name or manifest.get("short_name") != name:
    bad(f"/manifest.json answered {s} named {manifest.get('name')!r}, not {name!r}")
s, h, b = get("/sitemap-index.xml")
if s != 200 or f"{origin}/sitemap-0.xml" not in b.decode():
    bad(f"/sitemap-index.xml answered {s} without the site's sitemap")
s, h, b = get("/sitemap-0.xml")
if s != 200 or f"{origin}/fr/products/" not in b.decode() or f"{origin}/guides/intro/" not in b.decode():
    bad(f"/sitemap-0.xml answered {s} without the French pages and the docs on {origin}")
s, h, b = get("/robots.txt")
if s != 200 or f"Sitemap: {origin}/sitemap-index.xml" not in b.decode():
    bad(f"/robots.txt answered {s} without the site's sitemap line")

# The template's security headers (public/_headers, its vercel.json's).
s, h, _ = get("/")
csp = h.get("content-security-policy") or ""
if "default-src 'self'" not in csp or h.get("x-frame-options") != "SAMEORIGIN" or h.get("x-content-type-options") != "nosniff":
    bad(f"/ is served without the template's security headers ({csp[:60]!r}, {h.get('x-frame-options')!r})")

# Directory pages, as the site links them: /products redirects to /products/.
s, h, _ = get("/products")
if s not in (301, 307, 308) or not (h.get("location") or "").endswith("/products/"):
    bad(f"/products answered {s} → {h.get('location')!r}, not a redirect to /products/")

# An unknown path: the site's own 404 page, with a 404 — the French one under
# /fr/ (the Worker), as the template's Vercel rewrite served it.
s, h, b = get("/no-such-page")
page = b.decode()
if s != 404 or title(page) != f"Page Not Found | {name}" or '<html lang="en"' not in page:
    bad(f"/no-such-page answered {s} titled {title(page)!r}")
for path in ("/fr/no-such-page", "/fr/blog/no-such-post/"):
    s, h, b = get(path)
    page = b.decode()
    if s != 404 or title(page) != f"Page Non Trouvée | {name}" or '<html lang="fr"' not in page:
        bad(f"{path} answered {s} titled {title(page)!r}, not the French 404 page")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /, the marketing pages in English and French, a product, a post, an insight, the docs in seven languages and their search index, the manifest, the crawlers' files, the security headers, directory URLs and both 404s — the site's own, named {name!r}")
PY

echo "e2e.test.sh: ok"
