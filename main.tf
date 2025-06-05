variable "project_name" {
  type    = string
  default = "dbt_airflow_project"
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "docker" {}

resource "docker_network" "local_net" {
  name = "${var.project_name}_net"
}

resource "docker_volume" "airflow_dags" {
  name = "${var.project_name}_airflow_dags"
}
resource "docker_volume" "airflow_logs" {
  name = "${var.project_name}_airflow_logs"
}
resource "docker_volume" "airflow_plugins" {
  name = "${var.project_name}_airflow_plugins"
}
resource "docker_volume" "dbt_models" {
  name = "${var.project_name}_dbt_models"
}

resource "docker_image" "postgres" {
  name = "postgres:15"
}

resource "docker_container" "postgres" {
  name  = "${var.project_name}_postgres"
  image = docker_image.postgres.name

  env = [
    "POSTGRES_USER=airflow",
    "POSTGRES_PASSWORD=airflow",
    "POSTGRES_DB=airflow"
  ]

  ports {
    internal = 5432
    external = 5432
  }

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "docker_image" "airflow" {
  name = "apache/airflow:2.8.1-python3.10"
}

resource "docker_container" "airflow" {
  name  = "${var.project_name}_airflow"
  image = docker_image.airflow.name
  depends_on = [docker_container.postgres]

  env = [
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"
  ]

  ports {
    internal = 8080
    external = 8080
  }

  volumes = [
    "${docker_volume.airflow_dags.name}:/opt/airflow/dags",
    "${docker_volume.airflow_logs.name}:/opt/airflow/logs",
    "${docker_volume.airflow_plugins.name}:/opt/airflow/plugins"
  ]

  command = ["bash", "-c", "airflow db upgrade && airflow webserver"]

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "docker_image" "dbt" {
  name = "ghcr.io/dbt-labs/dbt:1.7.8"
}

resource "docker_container" "dbt" {
  name  = "${var.project_name}_dbt"
  image = docker_image.dbt.name

  env = [
    "DBT_PROFILES_DIR=/usr/app"
  ]

  volumes = [
    "${docker_volume.dbt_models.name}:/usr/app"
  ]

  working_dir = "/usr/app"
  command     = ["tail", "-f", "/dev/null"]

  networks_advanced {
    name = docker_network.local_net.name
  }
}

resource "null_resource" "project_setup" {
  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash
set -e
mkdir -p orchestrate/dags
mkdir -p transforms/models
mkdir -p transforms/data

cat <<EOF > .gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl

# dbt
transforms/target/
transforms/dbt_modules/
transforms/logs/

# Airflow
orchestrate/logs/
orchestrate/__pycache__/

# Python cache
__pycache__/
*.pyc
*.pyo
*.pyd

# VSCode config
.vscode/

# MacOS
.DS_Store
EOF

cat <<EOF > transforms/dbt_project.yml
name: transforms
version: "1.0"
config-version: 2

profile: dev

model-paths: ["models"]
seed-paths: ["data"]
target-path: "target"
clean-targets: ["target", "dbt_modules"]

models:
  transforms:
    +materialized: view
EOF

cat <<EOF > transforms/models/my_first_model.sql
-- models/my_first_model.sql
select *
from {{ ref('my_seed_data') }}
where id is not null
EOF

cat <<EOF > transforms/data/my_seed_data.csv
id,name
1,Alice
2,Bob
3,Charlie
EOF

cat <<EOF > orchestrate/dags/example_dbt_dag.py
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2024, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'dbt_transforms_example',
    default_args=default_args,
    description='Run dbt transformations from Airflow',
    schedule_interval=None,
    catchup=False,
) as dag:

    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command='docker exec ${var.project_name}_dbt dbt run',
    )

    dbt_run
EOF
EOT
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [docker_container.dbt, docker_container.airflow]
}

output "dbt_container" {
  value = docker_container.dbt.name
}

output "airflow_web_ui" {
  value = "http://localhost:8080"
}

output "postgres_connection" {
  value = "postgresql://airflow:airflow@localhost:5432/airflow"
}
