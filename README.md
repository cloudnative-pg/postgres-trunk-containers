# Building PostgreSQL Container Images from the Development Trunk

This CloudNativePG project is designed to build PostgreSQL container images
directly from the PostgreSQL source code, providing developers with a seamless
way to test and deploy their patches in Kubernetes environments.

By default, these images are built from the `master` branch of the official
PostgreSQL repository, commonly known as the *trunk*. However, you can also
leverage additional workflows to:

- Build images from a specific branch in any PostgreSQL repository publicly
  accessible
- Build images from a selected patch in a PostgreSQL Commitfest

Additionally, these container images can be used to run the suite of end-to-end
(E2E) tests of CloudNativePG through the continuous delivery workflow.

The primary goal of this project is to provide daily feedback on the status of
the PostgreSQL trunk, helping to identify and address regressions early in the
development process.

## How to Build a Container Image for Your PostgreSQL Patch

If you are developing a patch for PostgreSQL and want a quick way to test it in
Kubernetes with CloudNativePG, you can fork this project on GitHub. From there,
navigate to the "Actions" menu and run the relevant workflow called "Container
Images from PostgreSQL sources", specifying your Git repository and branch.

The action summary provides all the details you need to effectively use the
image.

## How to Build a Container Image for a Patch in the Commitfest

If you're interested in testing a PostgreSQL patch from a Commitfest in
Kubernetes with CloudNativePG, you can fork this project on GitHub. Then, run
the designated workflow called "Container Images from Commitfest patch" from the
"Actions" menu, entering the Commitfest Patch ID.

The action summary provides all the details you need to effectively use the
image.

## Building images locally

If you want to build these images locally, first make sure you meet the
following [prerequisites](https://github.com/cloudnative-pg/postgres-containers/blob/main/BUILD.md#prerequisites).
To build and push every flavor (minimal, standard, and PostGIS), run:

```
docker buildx bake --push
```

By default, the build process assumes a registry server runs locally at `localhost:5000`.
You can either [deploy a disposable registry at localhost:5000](https://github.com/cloudnative-pg/postgres-containers/blob/main/BUILD.md#local-testing), or [specify a different registry](https://github.com/cloudnative-pg/postgres-containers/blob/main/BUILD.md#the-distribution-registry).

## Multi-architecture support

Images are built for both `linux/amd64` and `linux/arm64`.

Since compiling PostgreSQL from source is CPU-bound, CI builds each
architecture natively — on an amd64 and, respectively, an arm64 runner — and
then publishes a single multi-arch manifest by merging the two per-arch
images with `docker buildx imagetools create`. It deliberately avoids
cross-building `linux/arm64` through QEMU emulation on an amd64 runner, which
would multiply the compilation time. See
[`reusable-build.yml`](.github/workflows/reusable-build.yml) for details.

Building locally with `docker buildx bake` still targets both platforms by
default (see the `platforms` variable in `docker-bake.hcl`). Building
`linux/arm64` on an amd64 host (or vice versa) this way relies on QEMU
emulation, which the [prerequisites](https://github.com/cloudnative-pg/postgres-containers/blob/main/BUILD.md#prerequisites)
above set up; it is fine for a one-off local build, just slow for a full
PostgreSQL compile. To build only for your host architecture instead, add
`--set '*.platform=linux/amd64'` (or `linux/arm64`) to the command.

## License and Copyright

This software is licensed under the [Apache License 2.0](LICENSE).

Copyright © The CloudNativePG Contributors.

## Trademarks

*[Postgres, PostgreSQL, and the Slonik Logo](https://www.postgresql.org/about/policies/trademarks/)
are trademarks or registered trademarks of the PostgreSQL Community Association
of Canada and are used with their permission.*
