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
"Actions" menu, entering the Commitfest ID and patch ID.

The action summary provides all the details you need to effectively use the
image.

## License and Copyright

This software is licensed under the [Apache License 2.0](LICENSE).

Copyright © The CloudNativePG Contributors.

## Trademarks

*[Postgres, PostgreSQL, and the Slonik Logo](https://www.postgresql.org/about/policies/trademarks/)
are trademarks or registered trademarks of the PostgreSQL Community Association
of Canada and are used with their permission.*
