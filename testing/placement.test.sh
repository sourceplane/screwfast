#!/usr/bin/env bash
# TIER 1 — the tree is placed, branded, and made to answer.
#
# A real bootstrap is `orun new --run-hooks --resume` against a workspace: it
# places each phase, runs that phase's hooks, lands a pull request and watches
# the convergence. Everything in that sentence except the platform can run
# here, offline, and this file runs it:
#
#   1. the whole blueprint placed in one go — orun runs `validate` and
#      `plan --dry-run` inside the produced tree and says so; asserted, because
#      a future orun that stopped running them would weaken this tier in silence;
#   2. THE OFFLINE BOOTSTRAP (testing/lib/bootstrap.sh) — every phase placed in
#      order onto what the previous one landed, finished by the blueprint's OWN
#      `run:` hooks (rebrand, re-tenant, work-tree strip, the deferrals, the
#      retouch marker, the deployment record), each landing a commit;
#   3. the product it ends with: branded with no residue, carrying nothing of
#      the factory, re-tenanted, its gates restored, its record rendered;
#   4. what the product's own CI would do with the 01-product merge: `orun
#      plan` for a push to main over exactly that commit, onto the
#      repository's empty first commit — the site deployed to stage
#      and prod side by side, nothing on dev, the product's own Worker deployed
#      from the committed deploy config, the smoke and the secret refs the
#      product's own;
#   5. a `--resume` over the finished site places nothing and un-brands nothing.
#
# testing/e2e.test.sh goes on from here: it installs, builds and serves the
# product and runs its smoke against it.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git. No credential. The
# deployment-record probes reach the network if they can, and pass without it.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git; do
  command -v "$bin" >/dev/null || { echo "placement.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
fails=0
fail() { echo "  ✕ $*" >&2; fails=$((fails + 1)); }
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"

sets=()
while IFS=$'\t' read -r k v; do sets+=( --set "$k=$v" ); done < <(
  python3 - "$values" <<'PY'
import json, sys
for k, v in json.load(open(sys.argv[1])).items():
    if not k.startswith("_"):
        print(f"{k}\t{'true' if v is True else 'false' if v is False else v}")
PY
)

# ── 1. the whole blueprint, one placement ──────────────────────────────────
echo "── placing the whole blueprint at once (offline, no credential)"
whole="$scratch/whole"
mkdir -p "$whole"/{apps,infra,packages,tests}
for d in apps infra packages tests; do touch "$whole/$d/.gitkeep"; done
if ! orun new --blueprint "$root/repo-blueprint.yaml" --out "$whole" "${sets[@]}" > "$scratch/whole.log" 2>&1; then
  echo "FAIL: the placement did not run" >&2; tail -20 "$scratch/whole.log" >&2; exit 1
fi
# The line's wording moved between orun releases (v2.58: `repo gate: validate +
# plan --dry-run passed`; v2.79: `Verified  intent valid · N components …`).
grep -Eq "repo gate: validate \+ plan --dry-run passed|Verified +intent valid" "$scratch/whole.log" \
  || fail "the placement did not report the repo-scale gate (orun validate + plan --dry-run inside the tree)"
n="$(find "$whole" -type f -not -path '*/.orun/*' | wc -l | tr -d ' ')"
[ "$n" -ge 50 ] || fail "only $n files placed — that is not a site"
[ "$fails" -eq 0 ] && echo "   $n files placed; the repo-scale gate ran"

# ── 2. the offline bootstrap ───────────────────────────────────────────────
echo "── the offline bootstrap: every phase, its own hooks, a landing each"
tree="$scratch/$repo"     # named as the repository is: orun names the project after it
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
grep -E '^── ' "$scratch/bootstrap.log" | sed 's/^/  /'
commits="$(git -C "$tree" rev-list --count HEAD)"
[ "$commits" = 3 ] || fail "the repository has $commits commits, not its first one and one per phase (1 + 2)"

# ── 3. the product it ends with ────────────────────────────────────────────
echo "── the site it produced"
(cd "$tree" && node "$root/tooling/rebrand/rebrand.mjs" --verify --values .rebrand/values.json) > "$scratch/verify.log" 2>&1 \
  || { fail "rebrand --verify found the baseline's identity in the site:"; sed 's/^/      /' "$scratch/verify.log" >&2; }

python3 - "$tree" "$values" "$root" <<'PY' || fails=$((fails + 1))
import json, pathlib, re, subprocess, sys
import yaml
tree, values, root = pathlib.Path(sys.argv[1]), json.load(open(sys.argv[2])), pathlib.Path(sys.argv[3])
problems = []
def bad(m): problems.append(m)
repo, org, name, sub = values["reponame"], values["githuborg"], values["productname"], values["subdomain"]

tracked = subprocess.run(["git", "ls-files"], cwd=tree, capture_output=True, text=True, check=True).stdout.split()

# Nothing of the factory, nothing local, exactly the two context pages.
NEVER = (".baseline/", "specs/", "tasks/", "testing/", "hooks/", "docs/phases/",
         "tooling/rebrand/", "tooling/bootstrap/", ".github/workflows/baseline.yml",
         ".github/workflows/tag.yml", "BOOTSTRAP.md", "repo-blueprint.yaml", "blueprint.yaml")
for p in tracked:
    if any(p == n or p.startswith(n) for n in NEVER):
        bad(f"{p} is in the site — it is the factory")
    if re.search(r"(^|/)(\.env(\.local)?|\.dev\.vars|node_modules|\.orun|dist|\.wrangler|\.next|\.open-next)(/|$)", p):
        bad(f"{p} is in the site — a local or built file")
ai = {p for p in tracked if p.startswith("ai/")}
if ai != {"ai/context/deployment.md", "ai/context/operations.md"}:
    bad(f"ai/ in the site is {sorted(ai)}")

# The identity, where the site carries it.
site = (tree / "apps/web/src/site.ts").read_text()
if f"SITE_NAME = {json.dumps(name)};" not in site:
    bad(f"apps/web/src/site.ts does not name the site {name!r}")
comp = yaml.safe_load((tree / "apps/web/component.yaml").read_text())["spec"]["parameters"]
if comp["workerName"] != f"{repo}-web":
    bad(f"workerName is {comp['workerName']}, not {repo}-web")
if comp["workersDevSubdomain"] != sub:
    bad(f"workersDevSubdomain is {comp['workersDevSubdomain']}, not {sub}")
# The config the lane deploys must exist in the tree BEFORE a build: the lane's
# structure check runs `test -f` on it ahead of build-app.
if not (tree / "apps/web" / comp["wranglerConfig"]).is_file():
    bad(f"wranglerConfig {comp['wranglerConfig']} is not a file in the placed site — "
        f"the lane checks for it before it builds")
if f'"name": "{repo}-web"' not in (tree / "apps/web/wrangler.jsonc").read_text():
    bad(f"apps/web/wrangler.jsonc does not name the Worker {repo}-web")
# The origin a deploy builds for: the environment's SITE_URL, else its own
# workers.dev URL under the site's Worker name and subdomain. A local build's
# is astro.config.mjs's default, the domain placeholder the rebrand wrote.
want = f'PUBLIC_SITE_URL="${{SITE_URL:-https://{repo}-web-${{ORUN_ENVIRONMENT}}.{sub}.workers.dev}}"'
if not comp["buildCommand"].startswith(want):
    bad(f"buildCommand does not build for the site's origin: {comp['buildCommand'][:120]}")
astro_config = (tree / "apps/web/astro.config.mjs").read_text()
if f"export const LOCAL_ORIGIN = 'https://{repo}.example.com';" not in astro_config:
    bad(f"apps/web/astro.config.mjs does not default to the site URL https://{repo}.example.com")
# The social links, the home page's GitHub links and the docs' GitHub link
# are the site's own repository; the contact address is on its domain.
own = f"https://github.com/{values['githuborg']}/{repo}"
for rel in ("apps/web/src/data_files/navigation.ts", "apps/web/src/views/HomeView.astro", "apps/web/astro.config.mjs"):
    text = (tree / rel).read_text()
    if own not in text or "mearashadowfax" in text:
        bad(f"{rel} does not link the site's own repository ({own})")
if f"mailto:support@{repo}.example.com" not in (tree / "apps/web/src/components/sections/misc/ContactSection.astro").read_text():
    bad(f"the contact address is not on the site's domain ({repo}.example.com)")
# The copy names the company through the seam, not by a literal.
for rel in ("apps/web/src/copy/en.ts", "apps/web/src/copy/fr.ts", "apps/web/src/data_files/constants.ts"):
    if "${SITE_NAME}" not in (tree / rel).read_text() and "SITE_NAME" not in (tree / rel).read_text():
        bad(f"{rel} does not read the site's name from src/site.ts")
# The template's own writing stays the template's: its demo content keeps its
# fictional company's name, and the docs link its repository.
post = (tree / "apps/web/src/content/blog/en/post-1.md").read_text()
if "ScrewFast" not in post:
    bad("the template's demo post lost the name it was written under")
if "https://github.com/mearashadowfax/ScrewFast" not in (tree / "apps/web/src/content/docs/welcome-to-docs.mdx").read_text():
    bad("the docs' welcome page no longer links the template's repository")
if json.loads((tree / "package.json").read_text())["name"] != repo:
    bad("package.json is not named for the site")

# The intent: re-tenanted, no work tree, both gates back.
intent_text = (tree / "intent.yaml").read_text()
intent = yaml.safe_load(intent_text)
if intent["metadata"]["name"] != repo:
    bad(f"intent metadata.name is {intent['metadata']['name']}")
if intent["execution"]["state"]["workspace"] != values["orunWorkspace"]:
    bad(f"intent workspace is {intent['execution']['state']['workspace']}, not the site's")
if "work" in intent:
    bad("intent.yaml still declares the baseline's work tree")
if "promotion" not in intent["environments"]["prod"] or "@promotion-deferred" in intent_text:
    bad("prod's promotion gate was not restored by 03-docs")
if "github-push-main" not in intent["environments"]["dev"]["activation"]["triggerRefs"] or "@dev-lanes-deferred" in intent_text:
    bad("dev's push activation was not restored by 03-docs")
for env in ("stage", "prod"):
    want = f"https://{repo}-web-{env}.{sub}.workers.dev"
    if intent["environments"][env].get("url") != want:
        bad(f"environments.{env}.url is {intent['environments'][env].get('url')}, not {want}")
for page in (intent.get("repo") or {}).get("docs", {}).get("pages", []):
    if not (tree / page["path"]).exists():
        bad(f"intent repo.docs names {page['path']}, which the site does not have")

# The landings, as the phases made them.
if not re.search(r"^# orun: redeploy 01-product \S+$", (tree / "apps/web/component.yaml").read_text(), re.M):
    bad("apps/web/component.yaml carries no 01-product redeploy marker")
dep = (tree / "ai/context/deployment.md").read_text()
if "GENERATED by the `03-docs` phase" not in dep or f"https://{repo}-web-prod.{sub}.workers.dev" not in dep:
    bad("ai/context/deployment.md was not rendered for the site")
readme = (tree / "README.md").read_text()
if not readme.startswith(f"# {repo}\n") or "This site is **live**" not in readme:
    bad("README.md is not the site's, or its live-deployment section was not rendered")

# Provenance prose, over the BRANDED files.
PROV = re.compile(r"\bfork(ed)? (of|from)\b|\bbaseline (repo|repository|commit|tag)\b|repo-blueprint|BOOTSTRAP\.md", re.I)
for rel in ("README.md", "ai/context/operations.md", "ai/context/deployment.md"):
    for n, line in enumerate((tree / rel).read_text().splitlines(), 1):
        if PROV.search(line):
            bad(f"{rel}:{n} speaks of the factory: {line.strip()[:70]}")

# No file the site carries points at the factory's own paths — a comment that
# sends its owner to testing/ or the blueprint sends them somewhere their
# repository does not have.
FACTORY = re.compile(r"(?<![\w.-])(testing/|repo-blueprint|BOOTSTRAP\.md|\.baseline/|specs/epics|"
                     r"tooling/(rebrand|bootstrap)/|hooks/render-deployment-docs)")
for rel in tracked:
    if rel in (".rebrand/values.json", "pnpm-lock.yaml"):
        continue
    try:
        text = (tree / rel).read_text()
    except (UnicodeDecodeError, IsADirectoryError):
        continue
    for n, line in enumerate(text.splitlines(), 1):
        if FACTORY.search(line):
            bad(f"{rel}:{n} names a factory path: {line.strip()[:70]}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   {len(tracked)} tracked files; branded, re-tenanted, gates restored, record rendered")
PY

# ── 4. the product's own CI, over the 01-product merge ─────────────────────
# The one landing's push: from the repository's empty first commit to the
# whole site, as main sees it the moment the pull request merges.
echo "── orun plan in the site, for the push that merged 01-product"
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
git -C "$tree" checkout -q "$s01"
(cd "$tree" && orun validate --intent intent.yaml) > "$scratch/validate.log" 2>&1 \
  || { fail "orun validate refused the site's intent at 01-product"; tail -10 "$scratch/validate.log" >&2; }
(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --changed \
   --base "$s00" --head "$s01" --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { fail "orun plan failed in the site at 01-product"; tail -15 "$scratch/plan.log" >&2; }
git -C "$tree" checkout -q main
python3 - "$scratch/plan.json" "$values" <<'PY' || fails=$((fails + 1))
import json, sys
plan, values = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
repo, sub, ws = values["reponame"], values["subdomain"], values["orunWorkspace"]
problems = []
def bad(m): problems.append(m)
jobs = {(j["component"], j["environment"]): j for j in plan["jobs"]}
if set(jobs) != {("web", "stage"), ("web", "prod")}:
    bad(f"the 01-product merge plans {sorted(jobs)}; it must deploy web to stage and prod and nothing else")
for (comp, env), j in jobs.items():
    if not j["profile"].endswith(".deploy"):
        bad(f"{comp}@{env} plans profile {j['profile']}, not a deploy")
    if j.get("dependsOn"):
        bad(f"{comp}@{env} waits on {j['dependsOn']} — during the bootstrap stage and prod deploy side by side")
    steps = {s["id"]: s.get("run") or "" for s in j["steps"]}
    for need in ("verify-app-structure", "build-app", "deploy", "smoke"):
        if need not in steps:
            bad(f"{comp}@{env} has no {need} step")
    if f'EFFECTIVE_WORKER_NAME="{repo}-web-{env}"' not in steps.get("deploy", ""):
        bad(f"{comp}@{env} deploys a Worker not named {repo}-web-{env}")
    if '--config "wrangler.jsonc"' not in steps.get("deploy", ""):
        bad(f"{comp}@{env} deploys with another config: {steps.get('deploy','').strip()[:120]}")
    smoke = steps.get("smoke", "")
    if ("hreflang=" not in smoke or "/products/item-a765/" not in smoke
            or "/welcome-to-docs/" not in smoke or "/pagefind/pagefind.js" not in smoke
            or "/fr/no-such-page" not in smoke or "<html lang=" not in smoke):
        bad(f"{comp}@{env}'s smoke is not the site's")
    if f'export WORKERS_DEV_SUBDOMAIN="{sub}"' not in steps.get("smoke", ""):
        bad(f"{comp}@{env}'s smoke probes another workers.dev subdomain")
    refs = {r["asEnv"]: r["ref"] for r in j.get("secretRefs") or []}
    for key in ("CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID"):
        ref = refs.get(key, "")
        if not ref.startswith(f"secret://{ws}/") or f"project:{repo}" not in ref:
            bad(f"{comp}@{env} resolves {key} from {ref or 'nowhere'} — not the site's workspace and project")
if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   web → stage + prod, deploy, side by side; Worker, deploy config, smoke and secrets the site's own")
PY

# ── 5. a resume over the finished site ────────────────────────────────────
echo "── --resume over the finished site"
before="$(git -C "$tree" status --porcelain; git -C "$tree" rev-parse HEAD)"
orun new --blueprint "$root/repo-blueprint.yaml" --out "$tree" --resume "${sets[@]}" > "$scratch/resume.log" 2>&1 \
  || { fail "--resume did not run"; tail -10 "$scratch/resume.log" >&2; }
after="$(git -C "$tree" status --porcelain; git -C "$tree" rev-parse HEAD)"
[ "$before" = "$after" ] || { fail "--resume changed the finished site:"; git -C "$tree" status --short | head -10 >&2; }
grep -qF "SITE_NAME = $(python3 -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1]))['productname']))" "$values");" "$tree/apps/web/src/site.ts" \
  || fail "--resume reverted the site's identity"
[ "$fails" -eq 0 ] && echo "   nothing placed again, nothing un-branded"

[ "$fails" -eq 0 ] || { echo "placement.test.sh: $fails failure(s)" >&2; exit 1; }
echo "placement.test.sh: ok"
