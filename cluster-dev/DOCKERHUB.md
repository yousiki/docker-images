# Docker Hub publishing — one-time setup

GHCR is blocked from some networks (e.g. parts of Alibaba Cloud). The workflow
mirrors the **`:base` variant** to Docker Hub when these two GitHub settings
are configured. Until they are configured, the workflow silently skips Docker
Hub and continues to push to GHCR only.

> The full `:latest` variant is GHCR-only — the cudnn-devel layer exceeds
> Docker Hub's per-blob upload limit (the API returns `400 Bad request` on
> the monolithic PUT). The full image is also unnecessary on Docker Hub:
> it's only useful from networks that already reach GHCR fine.

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

## How the conditional login works

```yaml
- name: Log in to Docker Hub
  if: github.event_name != 'pull_request' && matrix.push_dockerhub && vars.DOCKERHUB_USERNAME != ''
  ...
```

The login is gated by both `matrix.push_dockerhub` (only the `base` variant
sets this to `true`) and `vars.DOCKERHUB_USERNAME` (empty string when unset).
The image-name list passed to `docker/metadata-action` is gated the same way,
so when either condition is false the action only emits GHCR tags and Docker
Hub is bypassed cleanly.
