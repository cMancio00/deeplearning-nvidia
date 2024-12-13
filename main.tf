terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = data.coder_workspace_owner.me.name
}

data "coder_parameter" "ram" {
  name         = "ram"
  display_name = "RAM (GB)"
  description  = "Choose amount of RAM (min: 16 GB, max: 64 GB)"
  type         = "number"
  #icon         = ""
  mutable      = true
  default      = "32"
  order        = 2
  validation {
    min = 16
    max = 64
  }
}

# data "coder_parameter" "aName" {
#   name         = "aName"
#   display_name = "displayedName"
#   icon         = "svgUrl"
#   description  = "aDesctription"
#   type         = "string"
#   default      = "defaultOption"
#   mutable      = false
#   order        = 1
#   option {
#     name        = "option1"
#     description = "description1"
#     value       = "value1"
#     icon        = "svgUrl1"
#   }
#   option {
#     name        = "option2"
#     description = "description2"
#     value       = "value2"
#     icon        = "svgUrl2"
#   }
# }

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_image.deeplearning.id
  # icon        = ""

  item {
    key   = "RAM (GB)"
    value = data.coder_parameter.ram.value
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch                   = "amd64"
  os                     = "linux"
  startup_script = <<-EOT
    set -e

    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi

    # Install the latest code-server.
    # Append "--version x.x.x" to install a specific version of code-server.
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # Start code-server in the background.
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }

  metadata {
    display_name = "CPU Usage Workspace"
    interval     = 10
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
  }

  metadata {
    display_name = "RAM Usage Workspace"
    interval     = 10
    key          = "1_ram_usage"
    script       = "coder stat mem"
  }

  metadata {
    display_name = "GPU Usage"
    interval     = 10
    key          = "4_gpu_usage"
    script       = <<EOT
      nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader
    EOT
  }

  metadata {
    display_name = "GPU Memory Usage"
    interval     = 10
    key          = "5_gpu_memory_usage"
    script       = <<EOT
      nvidia-smi --query-gpu=utilization.memory --format=csv,noheader
    EOT
  }

  metadata {
    display_name = "Disk Usage"
    interval     = 600
    key          = "6_disk_usage"
    script       = "coder stat disk $HOME"
  }

}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "docker_image" "deeplearning" {
  name = "thesis:latest"
  # build {
  #   context    = "./images"
  #   dockerfile = "Dockerfile"
  #   tag        = ["thesis:latest"]
  #   build_args = {
  #     "" = ""
  #   }
  #   pull_parent = true
  # }

  keep_locally = true
}


resource "docker_container" "workspace" {
  count    = data.coder_workspace.me.start_count
  image    = docker_image.deeplearning.image_id
  memory   = data.coder_parameter.ram.value * 1024
  gpus     = "all"
  name     = "coder-${lower(data.coder_workspace.me.name)}"
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["192.168.1.197"]
  command  = ["sh", "-c", coder_agent.main.init_script]
  env      = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  restart  = "unless-stopped"

  devices {
    host_path = "/dev/nvidia0"
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

}
