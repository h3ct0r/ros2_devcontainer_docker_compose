# Multi-arch builds of every distro and target: <distro>-<target>, e.g. jazzy-desktop.
#
#   docker buildx bake --push release                                        # everything
#   docker buildx bake --load --set '*.platform=linux/arm64' jazzy-desktop   # one local image
#   docker buildx bake jazzy                                                 # all targets of one distro
#
# Tags: <IMAGE>:<distro>-<target>, <IMAGE>:<distro> (= full), <IMAGE>:latest (= jazzy-full).
# Humble also keeps the old <LEGACY_IMAGE>:<target> tags until its end of life (May 2027).
# Builds read the registry cache that CI pushes for each distro and architecture
# (<CACHE_IMAGE>:buildcache-<distro>-<arch>, mode=max, so it covers every target). The
# cache lives on GHCR, so builds make fewer requests against Docker Hub's rate limits.

variable "CACHE_IMAGE" {
  default = "ghcr.io/h3ct0r/ros2_dev"
}

variable "IMAGE" {
  default = "h3ct0rdcc/ros2_dev"
}

variable "LEGACY_IMAGE" {
  default = "h3ct0rdcc/ros2_humble_development"
}

variable "DEFAULT_DISTRO" {
  default = "jazzy"
}

# CI pushes each architecture by digest and creates the tags in a later step
variable "NO_TAGS" {
  default = ""
}

# Official multi-arch ROS bases, pinned by digest
function "base_image" {
  params = [distro]
  result = {
    humble  = "ros:humble-ros-base-jammy@sha256:566b87e6dfc48392189a9c32e594e84060fa9948de93b04e536f39475a1f6963"
    jazzy   = "ros:jazzy-ros-base-noble@sha256:103b6c417973394659af6804d4917cd489b91e5ed22eb7bef263025a3bed2410"
    lyrical = "ros:lyrical-ros-base-resolute@sha256:d9078270abaeae65497036085f1654c75ec0a95e2aca5ecf7ddc0846a6cd69e1"
  }[distro]
}

function "tags" {
  params = [distro, tgt]
  result = concat(
    ["${IMAGE}:${distro}-${tgt}"],
    tgt == "full" ? ["${IMAGE}:${distro}"] : [],
    tgt == "full" && distro == DEFAULT_DISTRO ? ["${IMAGE}:latest"] : [],
    distro == "humble" ? ["${LEGACY_IMAGE}:${tgt}"] : [],
    distro == "humble" && tgt == "full" ? ["${LEGACY_IMAGE}:latest"] : [],
  )
}

group "default" {
  targets = ["image"]
}

group "release" {
  targets = ["image", "legacy-humble-amd64", "legacy-humble-arm64"]
}

group "humble" {
  targets = ["humble-base", "humble-robot", "humble-desktop", "humble-full"]
}

group "jazzy" {
  targets = ["jazzy-base", "jazzy-robot", "jazzy-desktop", "jazzy-full"]
}

group "lyrical" {
  targets = ["lyrical-base", "lyrical-robot", "lyrical-desktop", "lyrical-full"]
}

target "_common" {
  context    = "."
  dockerfile = "docker/Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
}

target "image" {
  name     = "${distro}-${tgt}"
  matrix   = { distro = ["humble", "jazzy", "lyrical"], tgt = ["base", "robot", "desktop", "full"] }
  inherits = ["_common"]
  target   = tgt
  args = {
    ROS_DISTRO = distro
    BASE_IMAGE = base_image(distro)
  }
  tags       = NO_TAGS != "" ? [] : tags(distro, tgt)
  cache-from = [
    "type=registry,ref=${CACHE_IMAGE}:buildcache-${distro}-amd64",
    "type=registry,ref=${CACHE_IMAGE}:buildcache-${distro}-arm64",
  ]
}

# Single-arch tags kept for existing users of the old Humble image (same content as humble-full)
target "legacy-humble-amd64" {
  inherits  = ["humble-full"]
  platforms = ["linux/amd64"]
  tags      = ["${LEGACY_IMAGE}:amd64"]
}

target "legacy-humble-arm64" {
  inherits  = ["humble-full"]
  platforms = ["linux/arm64"]
  tags      = ["${LEGACY_IMAGE}:arm64"]
}
