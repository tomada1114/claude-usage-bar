# Conventions every workflow follows

The detail behind `changing-gates`' `.github/workflows/` section.

Conventions every workflow here follows, which `actionlint` (in `scripts/lint.sh`) and
the `zizmor` job partly check and review holds for the rest:

- every `uses:` of a remote action is pinned to a full commit SHA with a trailing
  `# vX.Y.Z` comment; a local `./.github/actions/…` action is exempt;
- a top-level `permissions:` as narrow as the work allows, and every job has a
  `timeout-minutes`;
- `actions/checkout` runs with `persist-credentials: false`;
- a new check goes into an existing job unless it needs a different runner, trigger, or
  permission footprint. Widening `permissions:` or adding a workflow that writes is a
  security-relevant change that needs sign-off, not a routine CI edit.
- a job's `name:` is what `.github/rulesets/main.json` requires as a status-check
  context, so renaming, removing, or re-triggering a job means editing that file in the
  same change; `scripts/checks/ruleset-contexts.sh` (`just check-harness`) fails while a
  required context matches no job in a `pull_request` workflow, and `just ruleset` then
  pushes the edited ruleset to the live repository (sign-off first).
