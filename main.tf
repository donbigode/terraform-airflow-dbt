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
  name         = "fishtownanalytics/dbt:1.0.0"
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

resource "docker_image" "airbyte_webapp" {
  name         = "airbyte/webapp:0.50.6"
  keep_locally = false
}

resource "docker_image" "airbyte_server" {
  name         = "airbyte/server:0.50.6"
  keep_locally = false
}

resource "docker_image" "airbyte_worker" {
  name         = "airbyte/worker:0.50.6"
  keep_locally = false
}

resource "docker_container" "airbyte_webapp" {
  name  = "${var.project_name}_airbyte_webapp"
  image = docker_image.airbyte_webapp.image_id
  ports {
    internal = 8000
    external = 8000
  }
  networks_advanced {
    name = docker_network.main.name
  }
}

resource "docker_container" "airbyte_server" {
  name  = "${var.project_name}_airbyte_server"
  image = docker_image.airbyte_server.image_id
  networks_advanced {
    name = docker_network.main.name
  }
}

resource "docker_container" "airbyte_worker" {
  name  = "${var.project_name}_airbyte_worker"
  image = docker_image.airbyte_worker.image_id
  networks_advanced {
    name = docker_network.main.name
  }
}