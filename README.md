# ingress-proxy

[![Build](https://github.com/blackswifthosting/ingress-proxy/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/blackswifthosting/ingress-proxy/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/blackswifthosting/ingress-proxy)](https://hub.docker.com/r/blackswifthosting/ingress-proxy)
[![Docker Image Version](https://img.shields.io/docker/v/blackswifthosting/ingress-proxy?sort=semver&label=version)](https://hub.docker.com/r/blackswifthosting/ingress-proxy/tags)
[![Image Size](https://img.shields.io/docker/image-size/blackswifthosting/ingress-proxy/latest)](https://hub.docker.com/r/blackswifthosting/ingress-proxy/tags)
[![License](https://img.shields.io/github/license/blackswifthosting/ingress-proxy)](LICENSE)

A lightweight reverse proxy Docker image built on [Caddy](https://caddyserver.com/), designed to forward HTTP and HTTPS traffic to a target host while preserving the original protocol.

## How it works

The proxy listens on port `80` and inspects the `X-Forwarded-Proto` header set by an upstream load balancer or ingress controller to determine how to reach the target:

- `X-Forwarded-Proto: https` → forwards to `TARGET_HOST:TARGET_HTTPS_PORT` over TLS
- `X-Forwarded-Proto: http` → forwards to `TARGET_HOST:TARGET_HTTP_PORT` over plain HTTP
- No header → falls back to plain HTTP

The original `Host` header is preserved, so the target sees the request exactly as intended.

## Why this is useful during migrations

When migrating infrastructure (e.g. switching cloud providers, moving between Kubernetes clusters, or transitioning from on-prem to cloud), you often need a temporary traffic bridge:

- Your DNS still points to the old entry point
- You want to redirect all traffic to the new infrastructure without changing DNS or client configuration
- Your load balancer terminates TLS and sets `X-Forwarded-Proto`, but the backend proxy must still reach the new target over the correct protocol

`ingress-proxy` sits between your load balancer and the target, routing HTTP and HTTPS traffic correctly based on the original protocol — with zero client-side changes.

```
Client → [Load Balancer / Ingress (sets X-Forwarded-Proto)] → ingress-proxy → Target Host
```

## Configuration

| Environment variable  | Default             | Description                          |
|-----------------------|---------------------|--------------------------------------|
| `TARGET_HOST`         | `www.example.tld`   | Hostname or IP of the target backend |
| `TARGET_HTTP_PORT`    | `80`                | Port used for plain HTTP forwarding  |
| `TARGET_HTTPS_PORT`   | `443`               | Port used for HTTPS forwarding       |

## Usage

```bash
docker run -d \
  -e TARGET_HOST=your-target-host \
  -e TARGET_HTTP_PORT=80 \
  -e TARGET_HTTPS_PORT=443 \
  -p 8080:80 \
  blackswifthosting/ingress-proxy
```

## Example — forwarding to www.google.com

Start the proxy locally targeting `www.google.com`:

```bash
docker run -d --name ingress-proxy \
  -e TARGET_HOST=www.google.com \
  -p 8080:80 \
  blackswifthosting/ingress-proxy
```

Test HTTP forwarding:

```bash
curl -si -H "Host: www.google.com" -H "X-Forwarded-Proto: http" http://localhost:8080/ | head -5
```

Test HTTPS forwarding:

```bash
curl -si -H "Host: www.google.com" -H "X-Forwarded-Proto: https" http://localhost:8080/ | head -5
```

Both commands should return a `200 OK` or `301` redirect response from Google, confirming that the proxy correctly reaches the target over the appropriate protocol.

Clean up:

```bash
docker rm -f ingress-proxy
```

## Base image

This image is built on [cgr.dev/chainguard/wolfi-base](https://images.chainguard.dev/directory/image/wolfi-base/overview) rather than the official `caddy` Docker image. The reason is CVE exposure: the official Caddy image is built on a general-purpose Linux distribution that ships many packages unrelated to running a proxy, each of which is a potential source of vulnerabilities. Wolfi is a minimal, purpose-built Linux distribution by Chainguard designed from the ground up to produce images with zero known CVEs. It ships only what is explicitly installed and receives rapid upstream patches.

Wolfi uses the APK package format (like Alpine) but is based on glibc instead of musl, which avoids the compatibility issues musl can introduce with certain Go and C software. Note that `wolfi-base` does include a shell and the APK package manager — a fully stripped image would require building with [apko](https://github.com/chainguard-dev/apko) instead of Docker. Using Docker here is a deliberate trade-off: it keeps the toolchain standard and familiar at the cost of a marginally larger attack surface from the retained shell.

The practical result: `docker scout cves` or `trivy image` will report no CVEs on this image, where the equivalent official Caddy image typically carries several medium-to-high severity findings from its base OS.

The weekly scheduled rebuild (see CI) ensures that even if a new CVE is disclosed in a dependency, the image is automatically rebuilt against the latest patched packages within days.

## Supply chain security

Every image published to Docker Hub includes two layers of SLSA attestation:

| Attestation | How it's embedded | What it proves |
|---|---|---|
| **SLSA provenance** (`mode=max`) | OCI attestation manifest alongside the image | Full build inputs: source commit, workflow, runner, build args |
| **SPDX SBOM** | OCI attestation manifest alongside the image | List of all software components in the image |
| **GitHub-signed provenance** | GitHub attestation store (Sigstore) | Cryptographically signed build provenance tied to the GitHub Actions run |

Verify the GitHub-signed provenance with the [GitHub CLI](https://cli.github.com/):

```bash
gh attestation verify oci://blackswifthosting/ingress-proxy:latest --owner blackswifthosting
```

Inspect the OCI-embedded attestations with [`docker buildx imagetools`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/):

```bash
docker buildx imagetools inspect blackswifthosting/ingress-proxy:latest --format '{{ json .Provenance }}'
docker buildx imagetools inspect blackswifthosting/ingress-proxy:latest --format '{{ json .SBOM }}'
```

## License

See [LICENSE](LICENSE).
