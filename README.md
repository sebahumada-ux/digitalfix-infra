DigitalFix - Infraestructura
Repositorio de infraestructura del proyecto DigitalFix, una plataforma de gestión de servicios técnicos desarrollada con arquitectura de microservicios.

Contiene la configuración del backend en AWS y un entorno independiente de Apache Kafka para la publicación, el consumo y el análisis de eventos.
Integrantes
- Sebastián Ahumada
- Benjamín Gutiérrez
Tecnologías utilizadas
- AWS EC2
- AWS API Gateway
- AWS VPC Link
- AWS Network Load Balancer
- Docker y Docker Compose
- Java 21 y Spring Boot
- Microsoft Entra ID y JWT
- Oracle Autonomous Database y Oracle Wallet
- RabbitMQ
- Apache Kafka
- Apache ZooKeeper
- Kafka UI
Estructura del repositorio
digitalfix-infra/
|
+-- README.md
+-- .gitignore
+-- infra/
|   +-- apps/
|       +-- compose.yml
|
+-- kafka/
    +-- docker-compose.yml
    +-- scripts/
        +-- init-topics.sh
Archivos principales:
- [`infra/apps/compose.yml`](infra/apps/compose.yml): despliegue de los microservicios del backend.
- [`kafka/docker-compose.yml`](kafka/docker-compose.yml): clúster Kafka, ZooKeeper, Kafka UI y servicios asociados.
- [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh): inicialización y verificación de tópicos.
Arquitectura del backend en AWS
El backend utiliza microservicios que se ejecutan mediante Docker Compose en AWS EC2. El acceso externo se realiza a través de API Gateway, con autenticación basada en Microsoft Entra ID.
Frontend Angular
       |
       v
AWS API Gateway
       |
       v
JWT Authorizer (Microsoft Entra ID)
       |
       v
VPC Link
       |
       v
Network Load Balancer
       |
       v
AWS EC2 - Docker Compose
       |
       v
DigitalFix BFF :8081
       |
       +---- Workorders :8080 ----+
       |                          |
       +---- Catalog :8082 -------+
                                  |
                                  v
                         Oracle Database
Componentes del backend
DigitalFix BFF
Centraliza las solicitudes del frontend y aplica controles de autenticación y autorización por roles.
- Java 21 y Spring Boot.
- Puerto interno: 8081.
- Comunicación con Workorders y Catalog.
- Validación de JWT y permisos.
Workorders
Gestiona las órdenes de trabajo, sus estados y los datos asociados a clientes.
- Java 21 y Spring Boot.
- Puerto interno: 8080.
- Persistencia mediante Oracle Database.
- Publicación de eventos de órdenes en Kafka cuando la integración está habilitada.
Catalog
Administra el catálogo de servicios técnicos.
- Java 21 y Spring Boot.
- Puerto interno: 8082.
- Persistencia mediante Oracle Database.
Seguridad y persistencia
La arquitectura del backend utiliza:
- Microsoft Entra ID: autenticación y emisión de tokens.
- JWT Authorizer: validación del token desde API Gateway.
- VPC Link y Network Load Balancer: conexión con servicios internos.
- Roles: Admin, Supervisor y Cliente.
- Oracle Database: persistencia de las entidades del negocio.
- Oracle Wallet: conexión segura con la base de datos.
Las credenciales, archivos .env y Oracle Wallet no deben incorporarse al repositorio. En el despliegue se suministran mediante variables de entorno y volúmenes protegidos.

La mensajería con RabbitMQ forma parte de la arquitectura del proyecto y se mantiene independiente de la infraestructura Kafka documentada a continuación.
Infraestructura Apache Kafka
El entorno Kafka complementa DigitalFix con procesamiento de eventos de órdenes y generación de métricas. Está definido en [`kafka/docker-compose.yml`](kafka/docker-compose.yml) y se ejecuta de forma independiente del Compose del backend en AWS.

La infraestructura utiliza:
- 3 brokers Apache Kafka.
- 3 nodos Apache ZooKeeper.
- 1 instancia de Kafka UI.
- 1 microservicio Kafka Admin.
- 1 microservicio Kafka Analytics.
- 1 servicio de inicialización de tópicos (kafka-init).
Arquitectura Kafka
DigitalFix Workorders
        |
        | Produce eventos de órdenes
        v
digitalfix.ordenes.eventos
        |
        v
Kafka Analytics (consumidor de órdenes)
        |
        | Valida, clasifica y produce métricas
        v
digitalfix.analitica.eventos
        |
        v
Kafka Analytics (consumidor de métricas)
        |
        v
Resumen de eventos en memoria
        |
        +---- API REST /api/analytics/resumen
        |
        +---- SSE /api/analytics/stream
                   |
                   v
             Dashboard Angular
Kafka Admin administra tópicos y consumer groups mediante una API REST. Kafka UI permite inspeccionar el clúster, sus tópicos y los mensajes publicados.

La publicación y el consumo de eventos se realizan mediante Spring Kafka. Las órdenes del negocio se persisten en Oracle; el resumen estadístico de Analytics se mantiene en memoria.
Tópicos configurados
El script de inicialización crea cuatro tópicos:
- digitalfix.ordenes.eventos: eventos de creación y cambios de estado de órdenes.
- digitalfix.analitica.eventos: métricas generadas por el procesamiento de órdenes.
- digitalfix.ordenes.eventos.DLT: mensajes del tópico de órdenes que no pudieron procesarse.
- digitalfix.analitica.eventos.DLT: mensajes del tópico de métricas que no pudieron procesarse.
Parámetros de configuración:
- Particiones por tópico: 3.
- Factor de replicación: 3.
- Mínimo de réplicas sincronizadas (min.insync.replicas): 2.
- Retención: 604800000 ms (7 días).
- Política de limpieza: delete.
Los parámetros se definen en [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh). El script utiliza --if-not-exists, por lo que no modifica la configuración de los tópicos que ya existan.
Consumer groups
Kafka Analytics emplea dos grupos independientes:
- digitalfix-analytics-workorders: consume digitalfix.ordenes.eventos y genera métricas.
- digitalfix-analytics-metrics: consume digitalfix.analitica.eventos y actualiza el resumen.
Los listeners utilizan concurrencia de tres consumidores. Los offsets y el lag pueden consultarse desde Kafka UI o desde la API de Kafka Admin.
Manejo de errores
El procesamiento implementa validaciones de eventos, registros de errores y políticas de reintento.
- Los eventos inválidos se detectan durante la deserialización o clasificación.
- Las fallas reintentables se gestionan mediante DefaultErrorHandler.
- Los eventos no recuperables se derivan al tópico .DLT correspondiente.
La configuración se encuentra en KafkaErrorsConfig.java del repositorio de Kafka Analytics.
Despliegue de Kafka con Docker Compose
La infraestructura espera que los repositorios de Kafka estén ubicados como carpetas hermanas:
DigitalFix/
|
+-- digitalfix-infra/
+-- ms-digitalfix-kafka-admin/
+-- ms-digitalfix-kafka-analytics/
+-- digitalfix-ms-workorders/
+-- frontend-digitalfix/
Ejecutar los comandos desde la carpeta padre DigitalFix/.
1. Iniciar Kafka, ZooKeeper y Kafka UI
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml up -d
2. Crear y verificar los tópicos
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
3. Construir e iniciar los microservicios Kafka
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
4. Comprobar el estado de los servicios
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps ps
5. Consultar los registros
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps logs --tail=50 kafka-admin kafka-analytics
6. Detener los contenedores
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps stop
La detención conserva los volúmenes del clúster. Evitar down -v cuando se requiera preservar los datos de Kafka.
Puertos y servicios
Puertos publicados por la configuración predeterminada:
- Kafka broker 1: localhost:19092.
- Kafka broker 2: localhost:19093.
- Kafka broker 3: localhost:19094.
- Kafka UI: http://localhost:8088.
- Kafka Admin: http://localhost:8090.
- Kafka Analytics: http://localhost:8091.
Los puertos externos pueden adaptarse según el entorno de ejecución, sin necesidad de cambiar los puertos internos del contenedor.
Endpoints principales
Kafka Admin
GET    /api/kafka/topics
GET    /api/kafka/topics/{nombre}
POST   /api/kafka/topics
PATCH  /api/kafka/topics/{nombre}/config
POST   /api/kafka/topics/{nombre}/partitions
DELETE /api/kafka/topics/{nombre}?confirmar=true

GET    /api/kafka/groups
GET    /api/kafka/groups/{grupo}/lag
Kafka Analytics
GET /api/analytics/resumen
GET /api/analytics/stream
El endpoint de streaming SSE se incorpora mediante la rama de desarrollo feature/actualizacion-tiempo-real de Kafka Analytics. No forma parte de su rama main.
Integración con el dashboard
La versión del frontend con monitoreo en tiempo real utiliza Server-Sent Events (SSE) para recibir notificaciones del procesamiento y actualizar sus indicadores sin recargar la página.
- Kafka: comunica eventos entre los microservicios.
- Analytics: procesa las métricas y notifica los cambios.
- SSE: transmite las notificaciones al navegador.
- Angular: consulta los datos actualizados y renueva el dashboard.
Esta funcionalidad está disponible en las ramas de desarrollo relacionadas:
- Kafka Analytics: feature/actualizacion-tiempo-real.
- Frontend: feature/dashboard-monitor-en-vivo.
Para un despliegue público es necesario revisar el control de acceso a los endpoints de streaming.
Despliegue del backend en AWS
El Compose del backend base se encuentra en [`infra/apps/compose.yml`](infra/apps/compose.yml) y es independiente del entorno Kafka.

Ejemplo de despliegue desde la carpeta que contiene los repositorios y el archivo de variables de entorno:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env build
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env up -d
Para verificar los contenedores:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env ps
Las variables y archivos de conexión a Oracle deben configurarse previamente en el entorno de despliegue.
Repositorios relacionados
- Kafka Admin
- Kafka Analytics
- Workorders
- Frontend DigitalFix
Evaluación: EV3 - Apache Kafka

Institución: Duoc UC
