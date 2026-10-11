#!/usr/bin/env bash
# Rebase this fork onto upstream and re-run the checks the fork's CI runs.
#
#   bash fork-sync.sh [branch]        # default: the branch you are on
#   FLUTTER=/path/to/flutter/bin/flutter bash fork-sync.sh
#
# It fetches upstream, rebases the branch onto upstream/main, regenerates the
# generated code (build_runner + intl_utils), formats, analyzes and runs the
# focused test suites. Nothing is pushed: when everything is green the script
# prints the push command (the rebase rewrites history, so it has to be a
# --force-with-lease push). Read FORK_FEATURES.md for the conflict rules.

set -euo pipefail

branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
flutter_bin="${FLUTTER:-flutter}"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

say() { printf '\n=== %s ===\n' "$1"; }

is_checkable_hotspot() {
  grep -E 'views/proxies|dashboard/widgets/service_status|models/config|arb/|l10n/' || true
}

if ! git remote get-url upstream >/dev/null 2>&1; then
  say "adding upstream remote"
  git remote add upstream https://github.com/chen08209/FlClash.git
fi

say "fetch upstream"
git fetch upstream --tags
git log -1 --format='upstream/main: %h %ad %s' --date=short upstream/main

say "commits we are behind"
git log --oneline HEAD..upstream/main || true

say "did upstream touch our files"
git diff --name-only HEAD...upstream/main | is_checkable_hotspot || echo '(none: the rebase should apply cleanly)'

say "rebase $branch onto upstream/main"
git switch "$branch"
git rebase upstream/main

say "regenerate models and localization"
dart run build_runner build --delete-conflicting-outputs
dart run intl_utils:generate

say "fetch packages and format"
"$flutter_bin" pub get
dart format lib test

say "analyze"
"$flutter_bin" analyze --no-fatal-infos

# `flutter test` runs the Go/Rust build hooks; with an empty core submodule that
# fails, and CI disables the same hook for its check job. Restored on exit.
backup="pubspec.yaml.fork-sync-backup"
cp pubspec.yaml "$backup"
restore() { mv -f "$backup" pubspec.yaml 2>/dev/null || true; }
trap restore EXIT

say "tests (setup.build_assets disabled for the run)"
sed -i '0,/build_assets: true/{s/build_assets: true/build_assets: false/}' pubspec.yaml

# A hook run that died (missing Go toolchain, killed shell) leaves .lock files
# behind, and then `flutter test` waits on them forever instead of compiling.
find .dart_tool -name '*.lock' -type f -delete 2>/dev/null || true

"$flutter_bin" test test/views/ test/l10n/
restore
trap - EXIT

cat <<EOF

=== next steps ===
1. test/lint/ only runs reliably on Linux (5 path-separator cases fail on
   Windows); the fork's CI runs it on ubuntu, so let the push decide.
2. push the rewritten branch:
     git push --force-with-lease origin $branch
3. the push triggers .github/workflows/fork-windows.yaml (Dart checks +
   Windows packages); upstream's own build.yaml runs beside it on the fork.
4. release from the run's artifacts (see FORK_FEATURES.md §5).
EOF
