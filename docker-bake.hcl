# Multi-arch builds of every target.
#
#   docker buildx bake --push release                       # all targets + :amd64/:arm64 aliases
#   docker buildx bake --load --set '*.platform=linux/arm64' desktop   # one local image
#
# CACHE=1 also pushes a registry build cache per target (needs push access).

variable "IMAGE" {
  default = "h3ct0rdcc/ros2_humble_development"
}

variable "CACHE" {
  default = ""
}

group "default" {
  targets = ["base", "robot", "desktop", "full"]
}

group "release" {
  targets = ["base", "robot", "desktop", "full", "full-amd64", "full-arm64"]
}

target "_common" {
  context    = "."
  dockerfile = "docker/Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
}

target "stage" {
  name       = tgt
  matrix     = { tgt = ["base", "robot", "desktop", "full"] }
  inherits   = ["_common"]
  target     = tgt
  tags       = tgt == "full" ? ["${IMAGE}:full", "${IMAGE}:latest"] : ["${IMAGE}:${tgt}"]
  cache-from = ["type=registry,ref=${IMAGE}:buildcache-${tgt}"]
  cache-to   = CACHE != "" ? ["type=registry,ref=${IMAGE}:buildcache-${tgt},mode=max"] : []
}

# Single-arch tags kept for existing users of :amd64 / :arm64 (same content as :full)
target "full-amd64" {
  inherits  = ["full"]
  platforms = ["linux/amd64"]
  tags      = ["${IMAGE}:amd64"]
  cache-to  = []
}

target "full-arm64" {
  inherits  = ["full"]
  platforms = ["linux/arm64"]
  tags      = ["${IMAGE}:arm64"]
  cache-to  = []
}
