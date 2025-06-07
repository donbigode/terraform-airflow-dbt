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
  name         = "apache/airflow:2.8.4"
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
  command = [
    "bash",
    "-c",
    "airflow db init && airflow users create --username admin --password admin --firstname admin --lastname admin --role Admin --email admin@example.com || true && airflow scheduler & exec airflow webserver"
  ]
}


resource "local_file" "test_dag" {
  filename = "${path.module}/orchestrate/dags/test_dag.py"
  content  = <<EOT
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id="dbt_test_dag",
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False,
) as dag:
    run_dbt = BashOperator(
        task_id="run_dbt",
        bash_command="docker exec -t ${docker_container.dbt.name} dbt run --project-dir /usr/app",
    )
EOT
}

resource "local_file" "dbt_project" {
  filename = "${path.module}/dbt/dbt_project.yml"
  content  = <<EOT
name: test_project
dbt_version: 1.0.0
config-version: 2

model-paths: ["models"]

profile: test_project
EOT
}

resource "local_file" "dbt_profile" {
  filename = "${path.module}/dbt/profiles.yml"
  content  = <<EOT
test_project:
  target: dev
  outputs:
    dev:
      type: postgres
      host: postgres
      user: admin
      password: admin
      dbname: warehouse
      port: 5432
      schema: public
EOT
}

resource "local_file" "dbt_model" {
  filename = "${path.module}/dbt/models/test_model.sql"
  content  = "select 1 as id"
}
