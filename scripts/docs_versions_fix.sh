#!/usr/bin/env bash
# Refresh the deployed docs version metadata after Documenter's deploy.
#
# DocumenterVitepress deploys write `dev/siteinfo.js` with an empty
# DOCUMENTER_CURRENT_VERSION. The docs theme requires a truthy value there,
# otherwise the version dropdown falls back to listing only `dev`.
# The root `versions.js` is also only updated by legacy (pre-VitePress)
# deployments, so it is regenerated here from the folders that actually
# exist on the `gh-pages` branch.

set -euo pipefail

TARGET="${TARGET:?}"
case "$TARGET" in
  astroautomata)
    REPO="git@github.com:astroautomata/SymbolicRegression.jl.git"
    KEY="${DOCUMENTER_KEY_ASTRO:?}"
    ;;
  cambridge)
    REPO="git@github.com:ai-damtp-cam-ac-uk/symbolicregression.git"
    KEY="${DOCUMENTER_KEY_CAM:?}"
    ;;
  *)
    echo "Unknown DEPLOYMENT_TARGET: $TARGET — skipping."
    exit 0
    ;;
esac

mkdir -p ~/.ssh
printf '%s\n' "$KEY" > ~/.ssh/deploy_key
chmod 600 ~/.ssh/deploy_key
ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/deploy_key -o IdentitiesOnly=yes"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
git clone --depth 1 --branch gh-pages "$REPO" "$WORKDIR/site"
cd "$WORKDIR/site"

# 1. dev/siteinfo.js: fill in the current version.
if [ -f dev/siteinfo.js ]; then
  sed -i 's/var DOCUMENTER_CURRENT_VERSION = ""/var DOCUMENTER_CURRENT_VERSION = "dev"/' dev/siteinfo.js
fi

# 2. Regenerate versions.js from the version folders that exist here.
mapfile -t vdirs < <(find . -mindepth 1 -maxdepth 1 -type d -name 'v*' -printf '%f\n' | sort -rV)
versions=("dev")
[ -d stable ] && versions+=("stable")
versions+=("${vdirs[@]}")
newest="${vdirs[0]:-dev}"
newest="${newest#v}"

{
  echo "var DOC_VERSIONS = ["
  for v in "${versions[@]}"; do
    echo "  \"$v\","
  done
  echo "];"
  echo "var DOCUMENTER_NEWEST = \"$newest\";"
  echo "var DOCUMENTER_STABLE = \"stable\";"
} > versions.js

git config user.name "MilesCranmerBot"
git config user.email "miles.cranmer.bot@gmail.com"
git add versions.js dev/siteinfo.js
if git diff --cached --quiet; then
  echo "Version metadata already up to date."
  exit 0
fi
git commit -m "fix: refresh docs version metadata (siteinfo + versions.js)"
git push origin gh-pages
echo "Docs version metadata refreshed."
