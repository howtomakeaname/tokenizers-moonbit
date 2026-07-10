---
title: Docs Workflow
createTime: 2026/07/10 00:00:00
---

# Docs Workflow

The `main` branch owns the VuePress/Plume site source under `docs/`. This keeps
documentation changes next to code, tests and `PROGRESS.md` instead of requiring
a separate source branch.

## Local Commands

```bash
pnpm install --frozen-lockfile
pnpm docs:dev
pnpm docs:build
```

## Build Output

VuePress builds into `gh-pages-deploy/`. That directory is ignored locally and
uploaded by GitHub Actions as a Pages artifact.

```mermaid
flowchart LR
  A[main docs/] --> B[VuePress Plume build]
  B --> C[gh-pages-deploy]
  C --> D[GitHub Pages artifact deploy]
```

## CI Flow

The `Pages` workflow runs on pushes to `main` that touch docs or site tooling:

1. Checkout `main`.
2. Install Node and `pnpm`.
3. Run `pnpm install --frozen-lockfile`.
4. Build `docs/` into `gh-pages-deploy/`.
5. Deploy the artifact through GitHub Pages.
