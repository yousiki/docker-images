# Docker Hub publishing — one-time setup

GHCR is blocked from some networks (e.g. parts of Alibaba Cloud). The workflow
mirrors every push to Docker Hub when these two GitHub settings are configured.
Until they are configured, the workflow silently skips Docker Hub and continues
to push to GHCR only.

The mirror is implemented as a separate `regctl image copy` step (not a second
`images:` entry on `docker/build-push-action`) — Docker Hub's CDN rejects
buildx's monolithic blob PUT with `400 Bad request` for the large cudnn-devel
layer in the full image. regctl uses chunked uploads which work for any size.

## 1 — Create a Docker Hub access token

1. Sign in at <https://hub.docker.com/>.
2. **Account Settings → Personal access tokens → Generate new token**.
   - Description: `github-actions-docker-images`
   - Access permissions: **Read, Write, Delete** (Delete is optional but matches
     GitHub's default cleanup behavior).
   - Expiration: pick a sensible value (e.g. 1 year).
3. Copy the token — Docker Hub only shows it once.

> Tip: Docker Hub auto-creates a repository on first push, but you can also
> pre-create `<DOCKERHUB_USERNAME>/cluster-dev` to set its visibility and
> description in advance.

## 2 — Add the secret + variable to this GitHub repo

Repo → **Settings → Secrets and variables → Actions**.

**Secrets** tab → **New repository secret**:

| Name              | Value                                  |
|-------------------|----------------------------------------|
| `DOCKERHUB_TOKEN` | the access token from step 1            |

**Variables** tab → **New repository variable**:

| Name                 | Value                                              |
|----------------------|----------------------------------------------------|
| `DOCKERHUB_USERNAME` | your Docker Hub username (e.g. `yousiki`) |

> Username is a *variable* (visible) rather than a *secret* because the Docker
> Hub image path needs to appear in build logs — secrets are masked, which
> would corrupt the image reference. The token stays a secret.

## 3 — Trigger a build

Either push a commit to `main` that touches `cluster-dev/**`, or run the
workflow manually:

```
Actions → cluster-dev → Run workflow
```

You should now see a **`Log in to Docker Hub`** step that runs (instead of
being skipped), and the **`Build and push`** step pushing tags to both
registries.

## 4 — Pull from Alibaba Cloud (or any GHCR-blocked network)

```bash
docker pull docker.io/<DOCKERHUB_USERNAME>/cluster-dev:base
docker run --rm --gpus all docker.io/<DOCKERHUB_USERNAME>/cluster-dev:base uv --version
```

If Docker Hub itself is also slow/blocked from your cluster, the next step is
to set up an Alibaba Cloud Container Registry (ACR) instance and add a third
login step — let me know and I'll wire it in.

## How the conditional mirror works

```yaml
- name: Install regctl
  if: github.event_name != 'pull_request' && (...) && vars.DOCKERHUB_USERNAME != ''
  ...

- name: Mirror GHCR -> Docker Hub
  if: github.event_name != 'pull_request' && (...) && vars.DOCKERHUB_USERNAME != ''
  run: |
    regctl registry login ghcr.io -u "$GHCR_USER" -p "$GHCR_PASS"
    regctl registry login docker.io -u "$DH_USER" -p "$DH_PASS"
    while IFS= read -r ghcr_ref; do
      tag="${ghcr_ref##*:}"
      regctl image copy "$ghcr_ref" "docker.io/$DH_USER/cluster-dev:$tag"
    done <<< "$GHCR_TAGS"
```

`vars.DOCKERHUB_USERNAME` evaluates to an empty string when the variable is
unset, so both regctl steps are skipped and Docker Hub is bypassed cleanly.
Once you set the variable + token, the mirror starts running and every tag
that the GHCR build produces gets copied to Docker Hub.
