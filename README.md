dbt Airflow Project Infrastructure
==================================

Este projeto provisiona, via Terraform, uma infraestrutura local baseada em Docker para orquestrar pipelines de dados usando:

- Apache Airflow
- dbt
- PostgreSQL
- Airbyte

Tudo conectado em uma rede Docker customizada.

----------------------------------
Estrutura da Infra
----------------------------------

Serviço           | Imagem Docker                       | Porta Externa
------------------|--------------------------------------|---------------
PostgreSQL        | postgres:15                          | 5432
Airflow Web UI    | apache/airflow:2.8.1-python3.10      | 8080
dbt               | fishtownanalytics/dbt:1.0.0          | -
Airbyte WebApp    | airbyte/webapp:0.50.62               | 8000
Airbyte Server    | airbyte/server:0.50.62               | 8001
Airbyte Worker    | airbyte/worker:0.50.62               | -
Airbyte DB        | airbyte/db:0.50.62                   | -

----------------------------------
Como usar (execução local)
----------------------------------

Usuários Unix (Linux/macOS):
----------------------------

1. Subir a infraestrutura:
   make up

2. Acessar os serviços:
   Airflow: http://localhost:8080
   Airbyte: http://localhost:8000

3. Derrubar a infraestrutura:
   make down

4. Fazer uma limpeza completa (containers, volumes e estado Terraform):
   make clean

5. Recriar tudo do zero:
   make recreate

Usuários Windows (sem Make):
----------------------------

1. Subir a infraestrutura:
   terraform init
   terraform apply -auto-approve -var="project_name=dbt_airflow_project"

2. Derrubar a infraestrutura:
   terraform destroy -auto-approve -var="project_name=dbt_airflow_project"

3. Limpeza manual (Docker):
   docker rm -f (docker ps -aq)
   docker volume rm (docker volume ls -q)
   docker network rm dbt_airflow_project_net
   del /f .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

----------------------------------
Pré-requisitos
----------------------------------

- Docker: https://www.docker.com/
- Terraform: https://developer.hashicorp.com/terraform/install

Para usuários Unix:
- GNU Make: Instale com `brew install make` (macOS) ou `sudo apt install make` (Linux)

Para usuários Windows:
- Use Git Bash, WSL ou terminal com suporte a Docker e Terraform

----------------------------------
Estrutura Esperada do Projeto
----------------------------------

.
├── orchestrate/          # Contém DAGs do Airflow
│   └── dags/
├── transforms/           # Contém código dbt
├── main.tf               # Infraestrutura com Terraform
├── Makefile              # Comandos automatizados (Unix only)
├── clean.sh              # Script de limpeza total (Unix only)
└── README.md             # Este arquivo
