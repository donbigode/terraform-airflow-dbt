terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

variable "project_name" {
  type    = string
  default = "dbt_airflow_project"
}

provider "docker" {}

resource "docker_network" "local_net" {
  name = "${var.project_name}_net"
}

resource "docker_volume" "airbyte_data" {}
resource "docker_volume" "airflow_logs" {}
resource "docker_volume" "airflow_plugins" {}
resource "docker_volume" "dbt_models" {}

resource "docker_container" "postgres" {
  name  = "${var.project_name}_postgres"
  image = "postgres:15"
  restart = "always"

  env = [
    "POSTGRES_DB=airflow",
    "POSTGRES_USER=airflow",
    "POSTGRES_PASSWORD=airflow"
  ]

  mounts {
    target = "/var/lib/postgresql/data"
    type   = "volume"
    source = docker_volume.dbt_models.name
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U airflow"]
    interval = "5s"
    retries  = 5
  }

  networks_advanced {
    name = docker_network.local_net.name
  }

  ports {
    internal = 5432
    external = 5432
    ip       = "0.0.0.0"
    protocol = "tcp"
  }
}

resource "docker_container" "airflow" {
  name  = "${var.project_name}_airflow"
  image = "apache/airflow:2.8.1-python3.10"
  restart = "always"
  depends_on = [docker_container.postgres]

  command = [
    "bash",
    "-c",
    "airflow db upgrade && nohup airflow scheduler & airflow webserver"
  ]

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
  ]

  mounts {
    source = abspath("${path.module}/orchestrate/dags")
    target = "/opt/airflow/dags"
    type   = "bind"
  }

  mounts {
    source = docker_volume.airflow_logs.name
    target = "/opt/airflow/logs"
    type   = "volume"
  }

  mounts {
    source = docker_volume.airflow_plugins.name
    target = "/opt/airflow/plugins"
    type   = "volume"
  }

  networks_advanced {
    name = docker_network.local_net.name
  }

  ports {
    internal = 8080
    external = 8080
    ip       = "0.0.0.0"
    protocol = "tcp"
  }
}

resource "docker_container" "dbt" {
  name  = "${var.project_name}_dbt"
  image = "fishtownanalytics/dbt:1.0.0"
  restart = "always"
  depends_on = [docker_container.postgres]

  command = ["tail", "-f", "/dev/null"]

  env = [
    "DBT_PROFILES_DIR=/usr/app"
  ]

  mounts {
    source = abspath("${path.module}/transforms")
    target = "/usr/app"
    type   = "bind"
  }

  networks_advanced {
    name = docker_network.local_net.name
  }

  working_dir = "/usr/app"
}

resource "docker_container" "airbyte_db" {
  name  = "airbyte_db"
  image = "airbyte/db:0.50.38"
  restart = "always"

  env = [
    "POSTGRES_USER=airbyte",
    "POSTGRES_PASSWORD=password",
    "POSTGRES_DB=airbyte"
  ]

  mounts {
    target = "/var/lib/postgresql/data"
    type   = "volume"
    source = docker_volume.airbyte_data.name
  }

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "docker_container" "airbyte_server" {
  name  = "airbyte_server"
  image = "airbyte/server:0.50.38"
  restart = "always"

  env = [
    "AIRBYTE_ROLE=server",
    "DATABASE_USER=airbyte",
    "DATABASE_PASSWORD=password",
    "DATABASE_HOST=airbyte_db",
    "DATABASE_PORT=5432",
    "DATABASE_DB=airbyte"
  ]

  depends_on = [docker_container.airbyte_db]

  ports {
    internal = 8001
    external = 8001
    ip       = "0.0.0.0"
    protocol = "tcp"
  }

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "docker_container" "airbyte_webapp" {
  name  = "airbyte_webapp"
  image = "airbyte/webapp:0.50.38"
  restart = "always"

  env = [
    "AIRBYTE_ROLE=webapp",
    "AIRBYTE_API_HOST=http://airbyte_server:8001"
  ]

  depends_on = [docker_container.airbyte_server, docker_container.airbyte_db]

  ports {
    internal = 8000
    external = 8000
    ip       = "0.0.0.0"
    protocol = "tcp"
  }

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "docker_container" "airbyte_worker" {
  name  = "airbyte_worker"
  image = "airbyte/worker:0.50.38"
  restart = "always"

  env = [
    "AIRBYTE_ROLE=worker",
    "DATABASE_USER=airbyte",
    "DATABASE_PASSWORD=password",
    "DATABASE_HOST=airbyte_db",
    "DATABASE_PORT=5432",
    "DATABASE_DB=airbyte"
  ]

  depends_on = [docker_container.airbyte_server]

  networks_advanced {
    name = docker_network.local_net.name
  }
}
