# -----------------------------
# 📦 Project name
# -----------------------------
PROJECT_NAME=dbt_airflow_project
AIRFLOW_CONTAINER=$(PROJECT_NAME)_airflow

# -----------------------------
# 🗂 Check required directories
# -----------------------------
check-dirs:
	@mkdir -p orchestrate/dags transforms dbt
	@test -d ./orchestrate/dags || (echo "❌ Missing ./orchestrate/dags" && exit 1)
	@test -d ./transforms || (echo "❌ Missing ./transforms" && exit 1)

# -----------------------------
# 📦 Create Docker Volumes (optional)
# -----------------------------
create-volumes:
	@echo "📦 Creating required Docker volumes..."
	docker volume create airflow_logs || true
	docker volume create airflow_plugins || true
	docker volume create dbt_models || true

# -----------------------------
# 🚀 Terraform Infrastructure
# -----------------------------
up: check-dirs
	@echo "🚀 Starting infrastructure..."
	terraform init
	terraform apply -auto-approve -var="project_name=$(PROJECT_NAME)"
	@echo ""
	@echo "🌐 Services available:"
	@echo "🔗 Airflow: http://localhost:8080"

# -----------------------------
# 🧹 Clean Containers, Volumes, and State
# -----------------------------
clean:
	@echo "🧹 Cleaning Docker and Terraform state..."
	-docker ps -aq --filter "name=$(PROJECT_NAME)" | xargs -r docker rm -f
	-docker volume rm airflow_logs airflow_plugins dbt_models || true
	-docker volume prune -f
	-docker network ls --format '{{.Name}}' | grep -q "^$(PROJECT_NAME)_network$$" && docker network rm $(PROJECT_NAME)_network || true
	-rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
	-find . -type d -name '__pycache__' -exec rm -rf {} +
	@echo "✅ Clean complete."

# Remove only named Docker volumes (útil para montar caminhos corretos)
clean-volumes:
	-docker volume rm airflow_logs airflow_plugins dbt_models || true
	-docker volume prune -f

# -----------------------------
# ⛔ Destroy Infra
# -----------------------------
down:
	@echo "🛑 Destroying infrastructure..."
	terraform destroy -auto-approve -var="project_name=$(PROJECT_NAME)"
	@echo "✅ Infrastructure stopped."

stop: down

# -----------------------------
# ♻️ Recreate
# -----------------------------
recreate: clean up

# -----------------------------
# 🧪 DBT Commands
# -----------------------------
dbt-run:
	docker exec -it $(PROJECT_NAME)_dbt dbt run

dbt-seed:
	docker exec -it $(PROJECT_NAME)_dbt dbt seed

dbt-debug:
	docker exec -it $(PROJECT_NAME)_dbt dbt debug

dbt-shell:
	docker exec -it $(PROJECT_NAME)_dbt bash

# -----------------------------
# 📡 Airflow Commands
# -----------------------------
create-airflow-user:
	docker exec -it $(AIRFLOW_CONTAINER) bash -c "\
		airflow db migrate && \
		airflow users create \
			--username $(USERNAME) \
			--password $(PASSWORD) \
			--firstname $(FIRSTNAME) \
			--lastname $(LASTNAME) \
			--role Admin \
			--email $(EMAIL)"

airflow-open:
	open http://localhost:8080

airflow-shell:
	docker exec -it $(PROJECT_NAME)_airflow bash

airflow-webserver:
	docker exec -it $(PROJECT_NAME)_airflow airflow webserver

airflow-scheduler:
	docker exec -it $(PROJECT_NAME)_airflow airflow scheduler

airflow-trigger:
	docker exec -it $(PROJECT_NAME)_airflow airflow dags trigger example_dag

# -----------------------------
# 🔍 Logs & Status
# -----------------------------
logs:
	docker ps -a
	-docker logs $(PROJECT_NAME)_dbt || true
	-docker logs $(PROJECT_NAME)_airflow || true
