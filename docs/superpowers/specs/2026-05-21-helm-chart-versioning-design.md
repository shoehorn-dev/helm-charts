# Design: Per-chart versioning for helm-charts releases

Date: 2026-05-21

## Problem

`release-all.yaml` tags both charts (`shoehorn`, `shoehorn-k8s-agent`) in lockstep
from a single source — `shoehorn-platform/version.json`. `release.yaml` then sets
each chart's `version` from the git tag and `appVersion` from that same platform
`version.json`.

For the `shoehorn-k8s-agent` chart this is wrong: the agent is a separately
versioned component, with its own image tags published from
`shoehorn-dev/shoehorn-k8s-agents` (latest `v0.4.41`). Because the chart's image
tag defaults to `.Chart.AppVersion` (`_helpers.tpl`), the chart deploys
`docker.io/shoehorned/shoehorn-k8s-agent:<platform-version>` — a tag that does not
exist — so installs fail to pull the image.

The lockstep release and the platform-derived `appVersion` are the antipattern.

## Versioning model

Each chart's `version` **and** `appVersion` are set to the same number: the
version of the app that chart deploys.

| Chart                | `version` == `appVersion` source                          |
|----------------------|-----------------------------------------------------------|
| `shoehorn`           | `shoehorn-platform/version.json`                          |
| `shoehorn-k8s-agent` | latest tag of `shoehorn-dev/shoehorn-k8s-agents`          |

The git tag (`<chart>-v<version>`), `Chart.yaml: version`, `Chart.yaml: appVersion`,
and the deployed image tag all carry that one number.

`_helpers.tpl` and `values.yaml` need no change — `tag: "" # Defaults to
.Chart.AppVersion` becomes correct once `appVersion` holds the real agent version.
This is true for both the agent image and the netobserver image
(`shoehorned/shoehorn-netobserver`), which ships from the same
`shoehorn-k8s-agents` repo and shares the agent's version.

## `release.yaml` changes

### Inputs

Replace the `tag` + `app_version` `workflow_dispatch` inputs with:

- `chart` — `choice` of `shoehorn` / `shoehorn-k8s-agent` (required)
- `version` — optional override

### Step reorder and resolution logic

1. **Determine chart** — from the `chart` input (dispatch) or parsed from the tag
   prefix (push). Moved *before* version resolution.
2. **Resolve version** — precedence:
   1. explicit `version` input, else
   2. version parsed from the pushed tag (push events), else
   3. per-chart resolution:
      - `shoehorn`: `gh api repos/shoehorn-dev/shoehorn-platform/contents/version.json`
        (unchanged path).
      - `shoehorn-k8s-agent`:
        `git ls-remote --tags --sort=-v:refname https://github.com/shoehorn-dev/shoehorn-k8s-agents`
        → newest tag, strip `refs/tags/`, `^{}` dereference suffix, and a leading
        `v`. Unauthenticated — the repo is public, so no App-token change needed.
3. **Compute tag** `<chart>-v<version>`; create it if missing (dispatch only).
4. **Update Chart.yaml** — set **both** `version:` and `appVersion:` to the
   resolved version. (Today `version` comes from the tag and `appVersion` from
   `version.json` — that split is the bug.)
5. Changelog, dependency build, package, helm push, cosign sign, oras push,
   GitHub Release — unchanged.

The release App token keeps `repositories: helm-charts,shoehorn-platform` — still
needed for the `shoehorn` chart's `version.json` read.

## `release-all.yaml`

Deleted. Its lockstep — tagging both charts from one platform `version.json` — is
the antipattern. Releases are now one `release.yaml` `workflow_dispatch` per chart.

## Committed `Chart.yaml` cleanup

The workflow `sed`s `Chart.yaml` only inside the runner; the change is never
committed back, so the in-repo file stays stale (`appVersion: "0.5.22"`).

Correct `shoehorn-k8s-agent/Chart.yaml` to `version: 0.4.41` /
`appVersion: "0.4.41"` so source builds and ArtifactHub reflect reality.

## Error handling

- Empty or `null` resolved version → fail with a clear message.
- `git ls-remote` returns no tags → fail; do not silently default.
- Existing tag on a re-run → keep current behavior (skip tag creation, proceed).

## Testing

- `helm lint shoehorn-k8s-agent`.
- `helm template shoehorn-k8s-agent --set image.tag=""` → assert the rendered
  image is `docker.io/shoehorned/shoehorn-k8s-agent:0.4.41`.
- Verify the `git ls-remote --tags --sort=-v:refname` one-liner selects `v0.4.41`
  as the newest tag.
- Acceptance: one real `workflow_dispatch` of each chart.

## Notes / out of scope

- Already-published broken chart versions stay broken; a fresh release is required
  to ship a corrected chart.
- Cross-repo automation (the agent repo triggering helm-charts) was considered and
  rejected — releases are manual `workflow_dispatch`.
