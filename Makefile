# -----------------------------
# Projec name : dbt + Airflow
# -----------------------------
PROJECT := dbt_airflow_project

# -----------------------------
# Check directories
# -----------------------------
check-dirs:
	@mkdir -p orchestrate/dags transforms
	@test -d ./orchestrate/dags || (echo "❌ Missing ./orchestrate/dags" && exit 1)
	@test -d ./transforms || (echo "❌ Missing ./transforms" && exit 1)

# -----------------------------
# Terraforming Infraestructure
# -----------------------------
up: check-dirs
	@echo "🚀 Starting infrastructure..."
	terraform init
	terraform apply -auto-approve -var="project_name=$(PROJECT)"
	@echo ""
	@echo "🌐 Acesse os serviços:"
	@echo "🔗 Airflow: http://localhost:8080"
	@echo "🔗 Airbyte: http://localhost:8000"
	@echo ""

clean:
	@echo "🧹 Cleaning Docker and Terraform state..."

	# Remove contêineres relacionados ao projeto
	-docker ps -aq --filter "name=$(PROJECT)" | xargs -r docker rm -f

	# Remove volumes criados pelo Terraform (mais seguro: remove todos os volumes não usados)
	-docker volume prune -f

	# Remove a rede do projeto, se existir
	-docker network ls --format '{{.Name}}' | grep -q "^$(PROJECT)_net$$" && docker network rm $(PROJECT)_net || true

	# Remove arquivos de estado do Terraform
	-rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

	# Remove caches Python
	-rm -rf orchestrate/dags/__pycache__ transforms/__pycache__

	@echo "✅ Cleaned up Docker resources and Terraform state."

# -----------------------------
# Destroy Infrastructure
# -----------------------------
down:
	@echo "🛑 Stopping infrastructure...
	terraform destroy -auto-approve -var="project_name=$(PROJECT)"
	@echo "✅ Infrastructure stopped."
stop: down
	@echo "🛑 Stopping infrastructure...
	terraform destroy -auto-approve -var="project_name=$(PROJECT)"
	@echo "✅ Infrastructure stopped."
# -----------------------------
# Recreate Infrastructure

recreate: clean up

# -----------------------------
# DBT Commands
# -----------------------------
dbt-run:
	docker exec -it $(PROJECT)_dbt dbt run

dbt-seed:
	docker exec -it $(PROJECT)_dbt dbt seed

dbt-debug:
	docker exec -it $(PROJECT)_dbt dbt debug

dbt-shell:
	docker exec -it $(PROJECT)_dbt bash

# -----------------------------
# Airflow Commands
# -----------------------------
airflow-open:
	open http://localhost:8080

airflow-shell:
	docker exec -it $(PROJECT)_airflow bash

airflow-webserver:
	docker exec -it $(PROJECT)_airflow airflow webserver

airflow-scheduler:
	docker exec -it $(PROJECT)_airflow airflow scheduler

airflow-trigger:
	docker exec -it $(PROJECT)_airflow airflow dags trigger example_dag

# -----------------------------
# Logs and Status
# -----------------------------
logs:
	docker ps -a
	docker logs $(PROJECT)_dbt
	docker logs $(PROJECT)_airflow
