#!/usr/bin/env bash
# Builds a scratch Android-shaped repo. Usage: new-repo.sh <variant>
# Variants: on-develop | on-feature | dirty-secret | no-config | with-post-edit-check | narrowed-config
#           | full-config (every key a skill needs, for running skills rather than hooks)
set -eu
variant="${1:-on-feature}"
dir="$(mktemp -d)"
cd "$dir"
git init -q -b develop .
git config user.email t@example.com
git config user.name Test
mkdir -p app/src/main/java/ui fastlane .ai/project scripts
printf 'android {\n  defaultConfig {\n    versionCode 60\n    versionName "3.4.27"\n  }\n}\n' > app/build.gradle
: > fastlane/firebase_credentials.json          # empty on purpose: the rail matches the path
printf 'package ui\n' > app/src/main/java/ui/Screen.kt
if [ "$variant" = "narrowed-config" ]; then
  printf 'protected_branches: [develop]\nbuild:\n  gradle_file: app/build.gradle\n' \
    > .ai/project/android-workflow.yml
elif [ "$variant" != "no-config" ]; then
  printf 'protected_branches: [develop, main, master]\nbuild:\n  gradle_file: app/build.gradle\n' \
    > .ai/project/android-workflow.yml
fi
if [ "$variant" = "full-config" ]; then
  cat > .ai/project/android-workflow.yml <<'YML'
workflow_version: 0.2.0
app_tag: TEST
jira_base: https://eplayment.atlassian.net/browse/
base_branch: develop
protected_branches: [develop, main, master]
build:
  gradle_file: app/build.gradle
  lint_task: lintDebug
  test_task: testDebugUnitTest
release_notes:
  file: release_notes.txt
  mode: append
YML
  : > release_notes.txt
fi
if [ "$variant" = "with-post-edit-check" ]; then
  printf '#!/usr/bin/env bash\nprintf "post-edit-check-ran %%s\\n" "$1"\n' > scripts/check.sh
  chmod +x scripts/check.sh
  printf 'lint:\n  post_edit_checks: [scripts/check.sh]\n' >> .ai/project/android-workflow.yml
fi
git add -A >/dev/null
git commit -qm "initial"
git branch feature/TA-1234
case "$variant" in
  on-feature|with-post-edit-check|narrowed-config|full-config) git checkout -q feature/TA-1234 ;;
  dirty-secret) git checkout -q feature/TA-1234
                printf 'changed\n' > fastlane/firebase_credentials.json ;;
esac
printf '%s\n' "$dir"
