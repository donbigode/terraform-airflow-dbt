terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_network" "main" {
  name = "${var.project_name}_network"
}

resource "docker_image" "postgres" {
  name         = "postgres:15"
  keep_locally = false
}

resource "docker_container" "postgres" {
  name  = "${var.project_name}_postgres"
  image = docker_image.postgres.image_id
  env = [
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=admin",
    "POSTGRES_DB=warehouse"
  ]
  ports {
    internal = 5432
    external = 5432
  }
  networks_advanced {
    name = docker_network.main.name
  }
  healthcheck {
    test     = ["CMD", "pg_isready", "-U", "admin"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

resource "docker_image" "dbt" {
  # Atualizado para a versão mais recente do dbt
  name         = "ghcr.io/dbt-labs/dbt-core:1.8.8"
  keep_locally = false
}

resource "docker_container" "dbt" {
  name    = "${var.project_name}_dbt"
  image   = docker_image.dbt.image_id
  command = ["tail", "-f", "/dev/null"]
  networks_advanced {
    name = docker_network.main.name
  }
  volumes {
    host_path      = abspath("${path.module}/dbt")
    container_path = "/usr/app"
  }
}

resource "docker_image" "airflow" {
  name         = "apache/airflow:2.7.2"
  keep_locally = false
}

resource "docker_container" "airflow" {
  name  = "${var.project_name}_airflow"
  image = docker_image.airflow.image_id
  env = [
    "AIRFLOW__CORE__EXECUTOR=SequentialExecutor",
    "AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://admin:admin@${docker_container.postgres.name}:5432/warehouse",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False"
  ]
  ports {
    internal = 8080
    external = 8080
  }
  networks_advanced {
    name = docker_network.main.name
  }
  volumes {
    host_path      = abspath("${path.module}/orchestrate/dags")
    container_path = "/opt/airflow/dags"
  }
  command = ["bash", "-c", "airflow db init && airflow webserver"]
}

resource "docker_image" "airbyte" {
  # Versão pública estável conforme documentação do projeto
  name         = "airbyte/airbyte:0.50.38"
  keep_locally = false
}

resource "docker_container" "airbyte" {
  name  = "${var.project_name}_airbyte"
  image = docker_image.airbyte.image_id
  ports {
    internal = 8000
    external = 8000
  }
  env = [
    "AIRBYTE_ROLE=webapp",
    "INTERNAL_API_HOST=host.docker.internal:8001",
    "AIRBYTE_API_HOST=http://host.docker.internal:8001",
    "AIRBYTE_WORKSPACE_ROOT=/data",
    "CONFIG_ROOT=/data/config"
  ]
  command = ["sh", "-c", "/bin/bash /app.sh webapp"]
  volumes {
    host_path      = abspath("${path.module}/airbyte_data")
    container_path = "/data"
  }
  networks_advanced {
    name = docker_network.main.name
  }
}
