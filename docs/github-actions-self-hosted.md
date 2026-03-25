# GitHub Actions on `pi5-01`

This branch deploys both RCC Remote targets from a self-hosted GitHub Actions runner on `pi5-01`.

The runner host only needs:

- Docker
- SSH access to `homelab-rcc`
- the GitHub Actions runner service

Kamal itself runs inside the official `ghcr.io/basecamp/kamal:v2.10.1` container during diagnostics and deploy workflows.

## Targets

- `admin`: the Rails admin app from [`config/deploy.yml`](../config/deploy.yml)
- `rccremote`: the RCC daemon from [`config/deploy.rccremote.yml`](../config/deploy.rccremote.yml)

## Branch model

- Keep self-hosted deployment work on the `self-hosted` branch.
- Set the fork default branch to `self-hosted` once the repo-side workflows are in place.
- The deploy-related workflows are `workflow_dispatch` only. Nothing auto-builds or auto-deploys on push.

## Repo secrets

Create `.env.kamal.local` in this repo with:

```bash
SECRET_KEY_BASE=...
S3_ACCESS_KEY_ID=...
S3_SECRET_ACCESS_KEY=...
CLOUDFLARED_TOKEN=...
```

If you want separate Cloudflare tunnels later, you can use:

```bash
ADMIN_CLOUDFLARED_TOKEN=...
RCCREMOTE_CLOUDFLARED_TOKEN=...
```

When only `CLOUDFLARED_TOKEN` is present, the admin and `rccremote` targets both reuse it.

Then sync GitHub repo secrets with:

```bash
script/sync-github-secrets-from-kamal-env.sh joshyorko/rccremote-docker
```

This pushes:

- `SECRET_KEY_BASE`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `CLOUDFLARED_TOKEN`
- `ADMIN_CLOUDFLARED_TOKEN`
- `RCCREMOTE_CLOUDFLARED_TOKEN`
- `KAMAL_REGISTRY_PASSWORD` from `KAMAL_REGISTRY_PASSWORD` or `gh auth token`

If [`config/master.key`](../config/master.key) exists locally, the script also syncs `RAILS_MASTER_KEY`.

## Runner install

Install and register the runner on `pi5-01` as a system service with:

```bash
script/install-self-hosted-runner-on-pi5-01.sh joshyorko/rccremote-docker
```

What it does:

- creates a dedicated SSH key on `pi5-01` for `homelab-rcc`
- adds that public key to `kdlocpanda@homelab-rcc`
- adds a `homelab-rcc` host entry on `pi5-01`
- downloads the GitHub Actions runner for Linux ARM64
- registers it to the repo with labels `pi5-01`, `kamal`, `rccremote-docker`
- installs and starts it as a system service

The workflows expect `pi5-01` to be able to SSH to `homelab-rcc` without prompting.

## Publish workflow

`.github/workflows/publish-images.yml` runs only by manual dispatch.

It always publishes both GHCR images for the selected commit:

- `ghcr.io/joshyorko/rccremote-docker-admin:sha-<short_sha>`
- `ghcr.io/joshyorko/rccremote-docker-rccremote:sha-<short_sha>`

## Diagnostics workflow

`.github/workflows/diagnostics-self-hosted.yml` runs only by manual dispatch and does not deploy anything.

Recommended first run:

1. Run `diagnostics-self-hosted.yml` with `target=admin` and `command=summary`.
2. Run `diagnostics-self-hosted.yml` with `target=admin` and `command=app_logs`.
3. Repeat with `target=rccremote` once the admin path looks correct.

Diagnostics dispatch supports:

- `summary`: `kamal version`, `kamal details`, `kamal app version`, `kamal app containers`, and `kamal proxy details`
- `app_logs`: `kamal app logs --primary --lines N`
- `proxy_logs`: `kamal proxy logs --primary --lines N`
- `app_details`: `kamal app details`
- `proxy_details`: `kamal proxy details`
- `audit`: `kamal audit`

## Deploy workflow

`.github/workflows/deploy-self-hosted.yml` runs only by manual dispatch.

Recommended order:

1. Run `diagnostics-self-hosted.yml` for the chosen target.
2. Run `publish-images.yml`.
3. After the images exist in GHCR, run `deploy-self-hosted.yml` for the target you want.

Manual deploy dispatch supports:

- `target=admin` or `target=rccremote`
- `action=deploy` for a normal deploy
- `action=setup` for first-time setup

The workflow waits for the published GHCR tag and then runs:

- `kamal setup --skip-push --version sha-<short_sha>`
- or `kamal deploy --skip-push --version sha-<short_sha>`

inside the official Kamal container against the selected config file.
