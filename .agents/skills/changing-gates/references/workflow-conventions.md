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

## The gitleaks pin

`.github/workflows/gitleaks.yml` installs gitleaks from its release tarball, pinned by
`GITLEAKS_VERSION` and `GITLEAKS_SHA256` in the job's `env:`. Neither Dependabot nor
mise tracks that pin, so a Renovate regex manager in `.github/renovate.json` opens the
version bump. Renovate cannot derive a checksum it could verify, so the bump stays
half manual, and fail-closed: the PR changes only `GITLEAKS_VERSION`, the workflow's
`pull_request` trigger (scoped to edits of that file) runs the job on the PR, and the
install step's `sha256sum --check` fails until someone finishes it:

1. download `gitleaks_<version>_checksums.txt` from
   `https://github.com/gitleaks/gitleaks/releases/tag/v<version>`;
2. copy the `gitleaks_<version>_linux_x64.tar.gz` line's hash into `GITLEAKS_SHA256`;
3. check it against the tarball itself:
   `echo "<sha>  gitleaks_<version>_linux_x64.tar.gz" | shasum -a 256 -c`;
4. push it and confirm the PR's "Scan full git history for leaked credentials" run
   passes before merging.

Never make the step pass by dropping or loosening the checksum check.
