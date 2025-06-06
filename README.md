Projeto Terraform - Airflow e dbt
=================================

Descrição
---------
Este projeto usa Terraform para orquestrar um ambiente de dados local baseado em containers Docker. Ele inclui:
- Apache Airflow: Orquestração de pipelines de dados
- dbt (data build tool): Transformações SQL em data warehouse
- PostgreSQL: Banco de dados relacional para Airflow

Pré-requisitos
--------------
- Docker instalado e em execução
- Terraform >= 1.3.0
- Acesso a imagens públicas do DockerHub
- Sistemas suportados: Unix-like (macOS, Linux). Para Windows, recomenda-se WSL2 ou Docker Desktop.

Estrutura do Projeto
--------------------
- orchestrate/dags         → Código dos DAGs do Airflow
- transforms/              → Projetos dbt
- terraform/               → Arquivos .tf (infraestrutura)
- Makefile                 → Comandos utilitários

Como usar
---------
1. Inicialize o Terraform:

   terraform init

2. Suba a infraestrutura:

   make up

   # O prefixo dos containers é definido pela variável `PROJECT_NAME` do Makefile.
   # Ajuste-a se desejar usar um nome diferente.

3. Acesse os serviços:

   - Airflow:      http://localhost:8080 (login: admin / admin)
   - dbt (exec):   make dbt-run

Comandos Makefile úteis
-----------------------
make up            → Sobe todos os containers
make down          → Destroi todos os containers
make recreate      → Faz um destroy + up (limpo)
make dbt-run       → Executa o comando dbt run
make dbt-test      → Executa o comando dbt test
make dbt-debug     → Verifica configuração do dbt
make clean-volumes → Remove volumes persistentes

Observações
-----------
- O Airbyte usa imagens fixas na versão 0.50.38 por estabilidade.
- O container do dbt foi atualizado para a versão 1.8.8.
- Os caminhos montados no Airflow e dbt usam bind com `abspath()` no Terraform (funciona apenas com caminhos absolutos).
- Todos os containers compartilham a rede local criada pelo Terraform para facilitar a comunicação entre serviços.

Manutenção
----------
- Atualize as imagens com cuidado (ex: Airflow e dbt têm dependências fixas).
- Recomenda-se limpar volumes (`make clean-volumes`) ao trocar dados sensíveis como senhas ou nomes de bancos.
