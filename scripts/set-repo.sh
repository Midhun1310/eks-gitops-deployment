#!/usr/bin/env bash
# Point every manifest at YOUR GitHub repository.  usage: scripts/set-repo.sh <owner>/<repo>
set -euo pipefail
NEW="${1:?usage: $0 <owner>/<repo>}"
cd "$(dirname "$0")/.."
grep -rl "YOUR_GH_USER/devops-mk-platform" --exclude-dir=.git --exclude-dir=node_modules . \
  | xargs sed -i "s#YOUR_GH_USER/devops-mk-platform#${NEW}#g"
echo "Updated repository references to ${NEW}"
