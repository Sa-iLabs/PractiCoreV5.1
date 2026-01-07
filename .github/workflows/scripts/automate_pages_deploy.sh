#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   GITHUB_TOKEN="<personal_or_repo_token>" ./scripts/automate_pages_deploy.sh
# Requirements: git, curl, python3
#
# Notes:
# - The script pushes an empty commit to the current branch (it expects main).
# - It uses the GitHub Pages REST API to find the published site URL and then
#   polls the site until HTTP 200 or timeout.
# - Set PAGES_CUSTOM_DOMAIN as a repository secret if you require CNAME creation
#   via the workflow (the workflow already supports that).
#
OWNER="Sa-iLabs"
REPO="PractiCoreV5.1"
BRANCH="main"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN environment variable is required. Create a token with repo and workflow permissions and export it."
  exit 2
fi

# Ensure we are on the right branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$BRANCH" ]; then
  echo "Switching to branch $BRANCH"
  git checkout "$BRANCH"
fi

echo "Creating an empty commit to trigger the workflow on branch $BRANCH..."
git commit --allow-empty -m "ci: trigger Pages deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)" || true
git push origin "$BRANCH"

echo "Triggered push. Now polling Pages API for published site..."

API_URL="https://api.github.com/repos/${OWNER}/${REPO}/pages"
auth_header="Authorization: token ${GITHUB_TOKEN}"

attempts=40
interval=6
i=0
site_url=""

while [ $i -lt $attempts ]; do
  i=$((i+1))
  echo "Pages API attempt $i/$attempts..."
  pages_json=$(curl -s -H "$auth_header" -H "Accept: application/vnd.github.v3+json" "$API_URL" || echo "")
  # Try to extract html_url using python (no jq required)
  site_url=$(printf '%s' "$pages_json" | python3 -c "import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('html_url',''))
except Exception:
  sys.exit(0)")
  if [ -n "$site_url" ]; then
    echo "Pages reported URL: $site_url"
    break
  fi
  sleep "$interval"
done

if [ -z "$site_url" ]; then
  echo "ERROR: Pages API did not return a published site URL after $attempts attempts."
  echo "API response (last):"
  printf '%s\n' "$pages_json"
  exit 3
fi

echo "Polling published site $site_url until it returns HTTP 200..."

attempts=30
interval=5
i=0
while [ $i -lt $attempts ]; do
  i=$((i+1))
  status=$(curl -s -o /dev/null -w "%{http_code}" "$site_url" || echo "000")
  echo "Attempt $i/$attempts - HTTP status: $status"
  if [ "$status" = "200" ]; then
    echo "SUCCESS: Pages site is live at $site_url"
    exit 0
  fi
  sleep "$interval"
done

echo "ERROR: Published site did not return HTTP 200 after $attempts attempts."
exit 4
