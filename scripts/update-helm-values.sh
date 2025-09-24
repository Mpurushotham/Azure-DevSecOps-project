#!/usr/bin/env bash
# Usage: ./update-helm-values.sh <gitops-repo-dir> <image_repo> <tag>
set -euo pipefail
repo_dir="$1"
image_repo="$2"
tag="$3"
values_file="$repo_dir/helm/myapp/values.yaml"
if [ ! -f "$values_file" ]; then
  echo "values.yaml not found in $values_file"
  exit 2
fi
# update repository and tag
yq e '.image.repository = env(image_repo) | .image.tag = env(tag)' -i "$values_file"
cd "$repo_dir"
git add "$values_file"
git commit -m "ci: update image to ${image_repo}:${tag}"
git push origin HEAD
