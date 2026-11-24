#!/usr/bin/env bash
set -euo pipefail
umask 077

plan="$RUNNER_TEMP/dev.tfplan"
tf=(terraform -chdir=environments/dev)

fail() {
  echo "::error::$*" >&2
  exit 1
}

check_main() {
  local head
  head=$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/main" --jq .object.sha)
  [[ "$head" == "$GITHUB_SHA" ]] || fail "main moved. Dispatch a fresh plan."
}

check_workload() {
  # Screen before a single write. Bootstrap and retained ECR must be no-ops.
  "${tf[@]}" show -json "$plan" | jq -e '
    def workload: test("^module\\.(networking|security|iam|alb|compute|monitoring)\\.");
    .errored == false and .complete == true and
    all(.resource_changes[]? | select(.mode == "managed");
      if (.address | workload) then
        ((.previous_address // .address) | workload) and .change.importing == null
      else
        .change.actions == ["no-op"] and .previous_address == null and .change.importing == null
      end)
  ' >/dev/null || fail "Incomplete plan or change outside the workload boundary. Review with the bootstrap owner."
}

check_digest() {
  [[ "$PLAN_SHA256" =~ ^[0-9a-f]{64}$ ]] || fail "Invalid SHA-256."
  printf '%s  %s\n' "$PLAN_SHA256" "$plan" | sha256sum --check --status || fail "Plan digest mismatch."
}

case "$1" in
  verify-dispatch)
    check_main
    if [[ "$OPERATION" == plan ]]; then
      [[ -z "$PLAN_RUN_ID" && -z "$PLAN_SHA256" ]] || fail "Leave plan identifiers empty when planning."
    else
      [[ "$OPERATION" == apply && "$PLAN_RUN_ID" =~ ^[1-9][0-9]*$ && "$PLAN_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
        fail "Apply requires a plan run ID and its reviewed SHA-256."
      gh api "repos/$GITHUB_REPOSITORY/actions/runs/$PLAN_RUN_ID" |
        jq -e --arg sha "$GITHUB_SHA" --arg repo "$GITHUB_REPOSITORY" '
          .path == ".github/workflows/terraform-apply.yml" and .event == "workflow_dispatch" and
          .head_repository.full_name == $repo and .head_branch == "main" and .head_sha == $sha and
          .status == "completed" and .conclusion == "success" and .run_attempt == 1 and
          (now - (.created_at | fromdateiso8601) < 86400)
        ' >/dev/null || fail "Expected a successful, current-main plan run less than one day old."
    fi
    ;;
  plan)
    : "${TF_PLAN_PASSPHRASE:?Missing terraform-apply environment secret}"
    "${tf[@]}" plan -input=false -no-color -lock-timeout=5m -out="$plan" >"$plan.log" 2>&1 ||
      fail "Planning failed. Use a trusted terminal to inspect diagnostics."
    check_workload
    {
      echo "## Dev plan for \`$GITHUB_SHA\`"
      echo "Plan run: $GITHUB_RUN_ID"
      echo "SHA-256: \`$(sha256sum "$plan" | cut -d ' ' -f 1)\`"
      echo
      echo '| Address | Action |'
      echo '|---|---|'
      "${tf[@]}" show -json "$plan" | jq -r '
        .resource_changes[]? | select(.mode == "managed" and .change.actions != ["no-op"]) |
        "| `\(.address)` | \(.change.actions | join(" + ")) |"'
      echo
      echo 'Review the encrypted binary privately, including attribute values, image, replacements and cost, before dispatching apply.'
    } >>"$GITHUB_STEP_SUMMARY"
    gpg --batch --pinentry-mode loopback --passphrase-fd 3 --cipher-algo AES256 \
      --symmetric --output "$plan.gpg" "$plan" 3<<<"$TF_PLAN_PASSPHRASE"
    ;;
  decrypt)
    : "${TF_PLAN_PASSPHRASE:?Missing terraform-apply environment secret}"
    gpg --batch --pinentry-mode loopback --passphrase-fd 3 --output "$plan" \
      --decrypt "$plan.gpg" 3<<<"$TF_PLAN_PASSPHRASE"
    check_digest
    ;;
  apply)
    check_digest
    check_workload
    check_main
    "${tf[@]}" apply -input=false -no-color -lock-timeout=5m "$plan" >"$plan.log" 2>&1 ||
      fail "Apply failed. Inspect state and AWS before preparing a new plan. Partial changes are possible."
    ;;
  *) fail "Unknown workflow step." ;;
esac
