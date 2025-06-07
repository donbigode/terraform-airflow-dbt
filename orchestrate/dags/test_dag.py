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
        bash_command="docker exec -t dbt_airflow_project_dbt dbt run --project-dir /usr/app"
    )

