#!/usr/bin/env bash
# =============================================================================
# version-bump.sh -- Bump the project version using semantic versioning.
#
# Usage:
#   ./scripts/version-bump.sh <patch|minor|major>
#
# What it does:
#   1. Validates the bump type argument
#   2. Reads current version from package.json
#   3. Computes the new version
#   4. Updates package.json (without npm side effects)
#   5. Creates a git commit and tag
#   6. Prints next steps
# =============================================================================

set -euo pipefail

BUMP_TYPE="${1:-}"
VALID_TYPES=("patch" "minor" "major")

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ -z "$BUMP_TYPE" ]]; then
  echo "Usage: $0 <patch|minor|major>"
  exit 1
fi

if [[ ! " ${VALID_TYPES[*]} " =~ " ${BUMP_TYPE} " ]]; then
  echo "Error: Invalid bump type '$BUMP_TYPE'. Must be one of: ${VALID_TYPES[*]}"
  exit 1
fi

if [[ ! -f "package.json" ]]; then
  echo "Error: package.json not found in current directory."
  exit 1
fi

# ---------------------------------------------------------------------------
# Read current version
# ---------------------------------------------------------------------------
CURRENT_VERSION=$(node -p "require('./package.json').version")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

echo "Current version: v${CURRENT_VERSION}"

# ---------------------------------------------------------------------------
# Compute new version
# ---------------------------------------------------------------------------
case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "New version:     v${NEW_VERSION}"

# ---------------------------------------------------------------------------
# Update package.json
# ---------------------------------------------------------------------------
npm version "$NEW_VERSION" --no-git-tag-version --allow-same-version

echo ""
echo "Updated package.json to v${NEW_VERSION}"

# ---------------------------------------------------------------------------
# Git commit and tag
# ---------------------------------------------------------------------------
if git rev-parse --is-inside-work-tree &>/dev/null; then
  git add package.json package-lock.json 2>/dev/null || true
  git commit -m "chore: bump version to v${NEW_VERSION}"
  git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"

  echo ""
  echo "Created commit and tag v${NEW_VERSION}"
  echo ""
  echo "Next steps:"
  echo "  git push origin main --follow-tags"
else
  echo ""
  echo "Not in a git repository. Skipping commit and tag."
fi
