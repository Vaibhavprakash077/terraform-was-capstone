#!/usr/bin/env bash
set -euo pipefail
umask 077

plan="${RUNNER_TEMP:?}/dev.tfplan"
tf=(terraform -chdir=environments/dev)

fail() {
  echo "::error::$*" >&2
  exit 1
}

case "${1:-}" in
  plan)
    "${tf[@]}" plan -input=false -no-color -lock-timeout=5m -out="$plan" >/dev/null 2>&1 ||
      fail "Planning failed. Reproduce the plan in a trusted terminal for diagnostics."

    # Stream values only to jq. Permit managed changes only in workload modules.
    "${tf[@]}" show -json "$plan" 2>/dev/null | jq -e '
      def workload: test("^module\\.(networking|security|iam|alb|compute|monitoring)\\.");
      .errored == false and .complete == true and
      (.resource_changes | type == "array") and (.action_invocations | length == 0) and
      all(.resource_changes[] | select(.mode == "managed");
        if (.address | workload) then
          ((.previous_address // .address) | workload) and .change.importing == null
        else
          .change.actions == ["no-op"] and .previous_address == null and .change.importing == null
        end)
    ' >/dev/null 2>&1 || fail "Incomplete, unreadable or out-of-bound plan. Review with the bootstrap owner."
    ;;
  apply)
    head=$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/main" --jq .object.sha)
    [[ "$head" == "$GITHUB_SHA" ]] || fail "main moved. Review the new commit and dispatch a fresh run."
    "${tf[@]}" apply -input=false -no-color -lock-timeout=5m "$plan" >/dev/null 2>&1 ||
      fail "Apply failed. Inspect state and AWS before retrying. Partial changes are possible."
    ;;
  *) fail "Expected plan or apply." ;;
esac
