# DBT + Airflow + PostgreSQL em Docker via Terraform

Este template configura:

- Apache Airflow 2.8.1
- dbt-core 1.7.8
- PostgreSQL 15
- Estrutura de projeto com:
  - `transforms/` (dbt)
  - `orchestrate/` (Airflow)
- Provisionamento via Terraform com provider Docker

## Requisitos

- Docker
- Terraform 1.3+
- Make (opcional, mas recomendado)

## Como usar

```bash
# Subir os serviços
make up

# Rodar os seeds e transformações
make dbt-seed
make dbt-run

# Acessar o Airflow
make airflow-open
```

## Variáveis

- `project_name` (default: `dbt_airflow_project`) — define prefixos dos recursos Docker.

Para usar um nome diferente:

```bash
make up PROJECT=meu_projeto
```
