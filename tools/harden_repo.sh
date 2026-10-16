#!/usr/bin/env bash
# Hardens the settings of the public GitHub repository (M12, D-180). Run once after the repository
# exists, as its owner (`gh auth login` first):
#
#     bash tools/harden_repo.sh <owner>/<repo>                 # the settings below
#     bash tools/harden_repo.sh <owner>/<repo> --protect-main   # and main takes pull requests only
#     bash tools/harden_repo.sh <owner>/<repo> --dry-run        # print the commands, change nothing
#
# What it sets, and why:
#   - workflows get a read-only token by default and can't approve pull requests (the Pages
#     workflow asks for the little more it needs by itself);
#   - a workflow from a first-time contributor's pull request waits for your approval;
#   - Dependabot alerts and security updates (the actions are pinned to commit SHAs, and
#     .github/dependabot.yml proposes the new ones);
#   - secret scanning and push protection (a pushed key or token is refused);
#   - private vulnerability reporting (SECURITY.md sends reports there);
#   - no wiki and no projects (less to keep an eye on).
# --protect-main (for when friends start sending pull requests): changes to main go through a pull
# request, no force pushes, no deleting main; the owner can still push in an emergency
# (enforce_admins off). Each step prints what it did; a step that your GitHub plan doesn't offer
# says so and the rest go on. Needs the GitHub CLI (`gh`).

REPO="${1:-}"
if [ -z "$REPO" ] || [ "${REPO#*/}" = "$REPO" ]; then
	echo "Usage: bash tools/harden_repo.sh <owner>/<repo> [--protect-main] [--dry-run]" >&2
	exit 64
fi
shift
PROTECT=0
DRY=0
for arg in "$@"; do
	case "$arg" in
		--protect-main) PROTECT=1 ;;
		--dry-run) DRY=1 ;;
		*) echo "Unknown option $arg" >&2; exit 64 ;;
	esac
done

if [ "$DRY" = 0 ] && ! gh auth status > /dev/null 2>&1; then
	echo "Not logged in to GitHub: run  gh auth login  first." >&2
	exit 1
fi

failed=0
step() { # description, then the gh command
	local description="$1"
	shift
	if [ "$DRY" = 1 ]; then
		echo "would: $description"
		echo "       $*"
		return
	fi
	if "$@" > /dev/null 2>&1; then
		echo "done:  $description"
	else
		echo "FAILED (not available, or not allowed): $description"
		failed=$((failed + 1))
	fi
}

step "workflows: read-only token by default, no approving pull requests" \
	gh api -X PUT "repos/$REPO/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
step "workflows of first-time contributors need approval" \
	gh api -X PUT "repos/$REPO/actions/permissions/fork-pr-contributor-approval" -f approval_policy=first_time_contributors
step "Dependabot alerts" gh api -X PUT "repos/$REPO/vulnerability-alerts"
step "Dependabot security updates" gh api -X PUT "repos/$REPO/automated-security-fixes"
step "private vulnerability reporting" gh api -X PUT "repos/$REPO/private-vulnerability-reporting"
step "secret scanning and push protection" \
	gh api -X PATCH "repos/$REPO" -f "security_and_analysis[secret_scanning][status]=enabled" -f "security_and_analysis[secret_scanning_push_protection][status]=enabled"
step "no wiki, no projects; branches of merged pull requests are deleted" \
	gh repo edit "$REPO" --enable-wiki=false --enable-projects=false --delete-branch-on-merge

if [ "$PROTECT" = 1 ]; then
	protection='{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"required_approving_review_count":0,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}'
	if [ "$DRY" = 1 ]; then
		echo "would: protect main (pull requests only, no force pushes, no deletion)"
		echo "       echo '$protection' | gh api -X PUT repos/$REPO/branches/main/protection --input -"
	elif echo "$protection" | gh api -X PUT "repos/$REPO/branches/main/protection" --input - > /dev/null 2>&1; then
		echo "done:  main takes pull requests only"
	else
		echo "FAILED (not available, or not allowed): protecting main"
		failed=$((failed + 1))
	fi
fi

echo "$failed step(s) failed."
exit "$failed"
