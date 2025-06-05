PROJECT := dbt_airflow_project

up:
	terraform init && terraform apply -auto-approve -var="project_name=$(PROJECT)"

stop:
	terraform destroy -auto-approve -var="project_name=$(PROJECT)"

dbt-run:
	docker exec -it $(PROJECT)_dbt dbt run

dbt-seed:
	docker exec -it $(PROJECT)_dbt dbt seed

dbt-debug:
	docker exec -it $(PROJECT)_dbt dbt debug

airflow-open:
	open http://localhost:8080

dbt-shell:
	docker exec -it $(PROJECT)_dbt bash
