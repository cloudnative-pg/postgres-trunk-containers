#
# Copyright © contributors to CloudNativePG, established as
# CloudNativePG a Series of LF Projects, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

variable "environment" {
  default = "testing"
  validation {
    condition = contains(["testing", "production"], environment)
    error_message = "environment must be either testing or production"
  }
}

variable "registry" {
  default = "localhost:5000"
}

variable "insecure" {
  default = "false"
}

// Use the revision variable to identify the commit that generated the image
variable "revision" {
  default = "1"
}

variable "pgMajor" {
  default = "19"
}

fullname = ( environment == "testing") ? "${registry}/postgresql-trunk-testing" : "${registry}/postgresql-trunk"
now = timestamp()
title = "PostgreSQL Trunk Containers"
description = "PostgreSQL Trunk Containers for CloudNativePG operator"
authors = "The CloudNativePG Contributors"
url = "https://github.com/cloudnative-pg/postgres-trunk-containers"

target "default" {
  matrix = {
    tgt = [
      "minimal",
      "standard",
      "postgis"
    ]
    pgMajor = ["${pgMajor}"]
    base = ["debian:bookworm-slim"]
  }

  platforms = [
    "linux/amd64"
  ]

  dockerfile = "Dockerfile"
  name = "${tgt}"
  tags = [
    "${fullname}:${pgMajor}-${tgt}-${distroVersion(base)}",
    "${fullname}:${pgMajor}-${formatdate("YYYYMMDDhhmm", now)}-${tgt}-${distroVersion(base)}"
  ]
  context = "."
  target = "${tgt}"
  args = {
    PG_MAJOR = "${pgMajor}"
    BASE = "${base}"
  }

  output = [
    "type=image,registry.insecure=${insecure}",
  ]
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]
  annotations = [
    "index,manifest:org.opencontainers.image.created=${now}",
    "index,manifest:org.opencontainers.image.url=${url}",
    "index,manifest:org.opencontainers.image.source=${url}",
    "index,manifest:org.opencontainers.image.version=${pgMajor}",
    "index,manifest:org.opencontainers.image.revision=${revision}",
    "index,manifest:org.opencontainers.image.vendor=${authors}",
    "index,manifest:org.opencontainers.image.title=CloudNativePG PostgreSQL ${pgMajor} ${tgt}",
    "index,manifest:org.opencontainers.image.description=A ${tgt} PostgreSQL ${pgMajor} container image",
    "index,manifest:org.opencontainers.image.documentation=${url}",
    "index,manifest:org.opencontainers.image.authors=${authors}",
    "index,manifest:org.opencontainers.image.licenses=Apache-2.0",
    "index,manifest:org.opencontainers.image.base.name=docker.io/library/${tag(base)}",
  ]
  labels = {
    "org.opencontainers.image.created" = "${now}",
    "org.opencontainers.image.url" = "${url}",
    "org.opencontainers.image.source" = "${url}",
    "org.opencontainers.image.version" = "${pgMajor}",
    "org.opencontainers.image.revision" = "${revision}",
    "org.opencontainers.image.vendor" = "${authors}",
    "org.opencontainers.image.title" = "CloudNativePG PostgreSQL ${pgMajor} ${tgt}",
    "org.opencontainers.image.description" = "A ${tgt} PostgreSQL ${pgMajor} container image",
    "org.opencontainers.image.documentation" = "${url}",
    "org.opencontainers.image.authors" = "${authors}",
    "org.opencontainers.image.licenses" = "Apache-2.0"
    "org.opencontainers.image.base.name" = "docker.io/library/debian:${tag(base)}"
  }
}

function tag {
  params = [ imageName ]
  result = index(split(":", imageName), 1)
}

function distroVersion {
  params = [ imageName ]
  result = index(split("-", tag(imageName)), 0)
}
