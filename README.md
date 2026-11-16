
# DigitalFix - Infraestructura

Repositorio encargado de la configuración, administración y despliegue de la infraestructura tecnológica del proyecto **DigitalFix**, una plataforma de gestión de servicios técnicos basada en microservicios.

La infraestructura contempla servicios desplegados en AWS, persistencia en Oracle Database y sistemas de mensajería mediante RabbitMQ y Apache Kafka.

## Integrantes

- Sebastián Ahumada
- Benjamín Gutiérrez

## Tecnologías utilizadas

- AWS EC2
- AWS API Gateway
- AWS VPC Link
- AWS Network Load Balancer
- Docker
- Docker Compose
- Java 21
- Spring Boot
- Microsoft Entra ID
- JWT
- Oracle Autonomous Database
- Oracle Wallet
- RabbitMQ
- Apache Kafka
- Apache ZooKeeper
- Kafka UI

## Arquitectura

DigitalFix utiliza una arquitectura de microservicios que permite separar las responsabilidades del sistema.

La solución contempla dos componentes principales de infraestructura:

- **Backend AWS:** servicios de negocio, autenticación y persistencia.
- **Infraestructura Kafka:** publicación, consumo y procesamiento de eventos.

Ambos entornos cuentan con configuraciones independientes mediante Docker Compose.

## Arquitectura del backend

El backend principal utiliza AWS para gestionar el acceso a los microservicios.

```text
Angular / Cliente
        |
        v
AWS API Gateway
        |
        v
JWT Authorizer
Microsoft Entra ID
        |
        v
VPC Link
        |
        v
Network Load Balancer
        |
        v
AWS EC2
Docker Compose
        |
        v
DigitalFix BFF :8081
        |
        +------------------+
        |                  |
        v                  v
Workorders :8080      Catalog :8082
        |                  |
        +------------------+
                 |
                 v
           Oracle Database
```

## Componentes del backend

### DigitalFix BFF

Microservicio encargado de centralizar las solicitudes provenientes del frontend.

Características:

- Spring Boot y Java 21.
- Puerto interno `8081`.
- Comunicación con Workorders y Catalog.
- Validación de tokens JWT.
- Autorización mediante roles.

### Workorders

Microservicio encargado de gestionar las órdenes de trabajo.

Características:

- Spring Boot y Java 21.
- Puerto interno `8080`.
- Persistencia en Oracle Database.
- Creación y consulta de órdenes.
- Actualización y validación de estados.
- Publicación de eventos hacia Kafka.

### Catalog

Microservicio encargado de gestionar el catálogo de servicios técnicos.

Características:

- Spring Boot y Java 21.
- Puerto interno `8082`.
- Persistencia en Oracle Database.
- Consulta y administración de servicios.

## Seguridad

La infraestructura utiliza Microsoft Entra ID para la autenticación de usuarios y JWT para controlar el acceso a los servicios.

Flujo de autenticación:

```text
Usuario
   |
   v
Microsoft Entra ID
   |
   v
Access Token JWT
   |
   v
AWS API Gateway
   |
   v
JWT Authorizer
   |
   v
Microservicios DigitalFix
```

Roles utilizados:

- Admin
- Supervisor
- Cliente

Los servicios protegidos validan las credenciales y aplican las autorizaciones correspondientes.

## Oracle Database

DigitalFix utiliza Oracle Autonomous Database como sistema de persistencia para los datos del negocio.

Características:

- Almacenamiento de órdenes de trabajo.
- Persistencia del catálogo técnico.
- Conexión mediante Oracle Wallet.
- Credenciales administradas mediante variables de entorno.

Los archivos de Oracle Wallet y las contraseñas no deben almacenarse en el repositorio.

## Infraestructura RabbitMQ

RabbitMQ permite la comunicación asíncrona entre microservicios mediante colas de mensajes.

La arquitectura contempla:

- Clúster RabbitMQ de dos nodos.
- Exchanges de tipo direct y topic.
- Colas para diferentes procesos del sistema.
- Dead Letter Queues para mensajes fallidos.
- Microservicios productores y consumidores.
- Administración de recursos mediante API REST.

RabbitMQ se utiliza para los flujos de mensajería correspondientes a la operación de servicios.

## Infraestructura Apache Kafka

Apache Kafka se utiliza para el procesamiento de eventos asociados a las órdenes de trabajo.

La infraestructura está compuesta por:

- 3 brokers Kafka.
- 3 nodos ZooKeeper.
- 1 interfaz Kafka UI.
- 1 microservicio Kafka Admin.
- 1 microservicio Kafka Analytics.

Esta arquitectura permite distribuir los mensajes, mantener réplicas y procesar eventos de manera asíncrona.

## Arquitectura Kafka

```text
DigitalFix Workorders
        |
        | Producer
        v
digitalfix.ordenes.eventos
        |
        | Consumer
        v
Kafka Analytics
        |
        | Clasificación
        | Producer
        v
digitalfix.analitica.eventos
        |
        | Consumer
        v
Resumen de Analytics
        |
        +------------------+
        |                  |
        v                  v
    API REST              SSE
        |                  |
        +------------------+
                 |
                 v
         Dashboard Angular
```

Workorders publica eventos cuando se crean órdenes o se modifican sus estados.

Kafka Analytics recibe estos mensajes, valida su contenido y genera métricas que pueden consultarse mediante una API REST.

La versión de desarrollo del dashboard incorpora notificaciones SSE para actualizar automáticamente la información mostrada.

## Tópicos Kafka

La infraestructura contempla cuatro tópicos.

### Tópicos principales

- `digitalfix.ordenes.eventos`
- `digitalfix.analitica.eventos`

### Dead Letter Topics

- `digitalfix.ordenes.eventos.DLT`
- `digitalfix.analitica.eventos.DLT`

Los tópicos principales permiten procesar eventos de órdenes y generar métricas.

Los tópicos DLT reciben mensajes que no pudieron procesarse correctamente mediante los mecanismos de recuperación configurados.

## Configuración de tópicos

Los cuatro tópicos utilizan los siguientes parámetros:

- **Particiones:** 3.
- **Factor de replicación:** 3.
- **Réplicas mínimas sincronizadas:** 2.
- **Retención:** 7 días.
- **Política de limpieza:** `delete`.

La configuración se encuentra en:

`kafka/scripts/init-topics.sh`

El script permite crear los tópicos necesarios y verificar la configuración de los tópicos principales.

## Productores y consumidores

### Producer - Workorders

Workorders utiliza Spring Kafka para publicar eventos de órdenes.

Características:

- Publicación mediante `KafkaTemplate`.
- Mensajes JSON estructurados.
- Identificador de orden utilizado como key.
- Registro de resultados de publicación.

### Consumer - Kafka Analytics

Kafka Analytics utiliza `@KafkaListener` para consumir los mensajes.

Funciones:

- Recibir eventos de órdenes.
- Validar el contenido del mensaje.
- Clasificar los estados.
- Generar métricas.
- Publicar resultados en el tópico de analítica.
- Mantener contadores de eventos.

Los resúmenes de Analytics se conservan en memoria. La persistencia de órdenes corresponde a Oracle Database.

## Consumer Groups

La infraestructura utiliza dos grupos principales de consumidores:

```text
digitalfix-analytics-workorders
digitalfix-analytics-metrics
```

El primer grupo procesa los eventos provenientes de Workorders.

El segundo procesa las métricas publicadas por Analytics.

La configuración permite distribuir el consumo entre particiones y administrar los offsets de cada grupo.

## Manejo de errores

Kafka Analytics implementa mecanismos de control para el procesamiento de mensajes.

Características:

- Validación de eventos y estructuras JSON.
- Registro de errores en logs.
- Reintentos configurados para fallas reintentables.
- Recuperación hacia Dead Letter Topics.
- Continuidad del procesamiento ante mensajes inválidos.

La configuración se encuentra en:

`KafkaErrorsConfig.java`

## Kafka Admin

Kafka Admin es el microservicio encargado de administrar los recursos de Apache Kafka.

Funcionalidades:

- Crear tópicos.
- Listar y consultar tópicos.
- Modificar configuraciones.
- Aumentar particiones.
- Eliminar tópicos con confirmación.
- Consultar consumer groups.
- Revisar offsets y lag.
- Publicar eventos de demostración.

Puerto del microservicio:

`8090`

### Endpoints principales

```http
GET    /api/kafka/topics
GET    /api/kafka/topics/{nombre}
POST   /api/kafka/topics
PATCH  /api/kafka/topics/{nombre}/config
POST   /api/kafka/topics/{nombre}/partitions
DELETE /api/kafka/topics/{nombre}?confirmar=true

GET    /api/kafka/groups
GET    /api/kafka/groups/{grupo}/lag
```

## Kafka Analytics

Kafka Analytics es el microservicio encargado del consumo, procesamiento y clasificación de eventos.

Funcionalidades:

- Consumo de eventos Kafka.
- Generación de métricas.
- Clasificación de estados.
- Registro de eventos recientes.
- Consulta de estadísticas.
- Notificaciones SSE en la rama de desarrollo correspondiente.

Puerto del microservicio:

`8091`

### Endpoints principales

```http
GET /api/analytics/resumen
GET /api/analytics/stream
```

El endpoint `/stream` corresponde a la implementación SSE disponible en la rama `feature/actualizacion-tiempo-real`.

## Kafka UI

Kafka UI proporciona una interfaz web para visualizar y administrar la infraestructura Kafka.

Permite consultar:

- Brokers.
- Tópicos.
- Particiones.
- Réplicas.
- Mensajes.
- Consumer groups.
- Offsets.
- Lag de consumidores.

Puerto publicado:

`8088`

## Estructura del repositorio

```text
digitalfix-infra/
|
+-- README.md
|
+-- .gitignore
|
+-- infra/
|   |
|   +-- apps/
|       |
|       +-- compose.yml
|
+-- kafka/
    |
    +-- docker-compose.yml
    |
    +-- scripts/
        |
        +-- init-topics.sh
```

### Archivos principales

`infra/apps/compose.yml`

Configuración del backend principal de DigitalFix.

`kafka/docker-compose.yml`

Configuración del clúster Kafka, ZooKeeper, Kafka UI y los microservicios Kafka.

`kafka/scripts/init-topics.sh`

Inicialización y verificación de los tópicos Kafka.

## Docker Compose

La infraestructura Kafka se ejecuta mediante Docker Compose.

El archivo se encuentra en:

`kafka/docker-compose.yml`

Para construir los microservicios Kafka, la estructura de directorios debe contener los repositorios relacionados al mismo nivel.

```text
DigitalFix/
|
+-- digitalfix-infra/
|
+-- ms-digitalfix-kafka-admin/
|
+-- ms-digitalfix-kafka-analytics/
|
+-- digitalfix-ms-workorders/
|
+-- frontend-digitalfix/
```

## Despliegue de Kafka

Los siguientes comandos se ejecutan desde el directorio padre que contiene los repositorios.

### Iniciar Kafka

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml up -d
```

### Inicializar tópicos

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
```

### Iniciar Kafka Admin y Analytics

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
```

### Verificar contenedores

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps ps
```

### Consultar logs

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps logs --tail=50 kafka-admin kafka-analytics
```

### Detener servicios

```powershell
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps stop
```

El comando `stop` detiene los servicios sin eliminar los volúmenes persistentes de Kafka.

## Verificación de servicios

Con los servicios iniciados, se pueden consultar las siguientes direcciones:

### Kafka UI

`http://localhost:8088`

### Kafka Admin

`http://localhost:8090/api/kafka/topics`

### Kafka Analytics

`http://localhost:8091/api/analytics/resumen`

Los puertos publicados pueden modificarse según la configuración del entorno.

## Despliegue del backend AWS

La configuración principal del backend se encuentra en:

`infra/apps/compose.yml`

Los servicios se ejecutan mediante Docker Compose en AWS EC2.

Desde el directorio que contiene el repositorio de infraestructura y los archivos de configuración correspondientes:

### Construir imágenes

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  build
```

### Iniciar servicios

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  up -d
```

### Verificar servicios

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  ps
```

## Variables de entorno

La configuración sensible se administra mediante variables de entorno.

Ejemplos:

```text
WORKORDERS_DB_USERNAME
WORKORDERS_DB_PASSWORD
CATALOG_DB_USERNAME
CATALOG_DB_PASSWORD
AZURE_TENANT_ID
AZURE_CLIENT_ID
KAFKA_BOOTSTRAP_SERVERS
```

Los archivos `.env`, contraseñas y Oracle Wallet deben mantenerse fuera del control de versiones.

## Repositorios relacionados

### Kafka Admin

https://github.com/sebahumada-ux/ms-digitalfix-kafka-admin

### Kafka Analytics

https://github.com/sebahumada-ux/ms-digitalfix-kafka-analytics

### Workorders

https://github.com/sebahumada-ux/digitalfix-ms-workorders

### Frontend DigitalFix

https://github.com/sebahumada-ux/frontend-digitalfix

### Infraestructura

https://github.com/sebahumada-ux/digitalfix-infra

## Estado del proyecto

La infraestructura de DigitalFix contempla:

- Backend de microservicios en AWS.
- Autenticación mediante Microsoft Entra ID.
- Autorización mediante JWT y roles.
- Persistencia en Oracle Database.
- Mensajería con RabbitMQ.
- Clúster Apache Kafka con tres brokers.
- Administración REST mediante Kafka Admin.
- Procesamiento de eventos mediante Kafka Analytics.
- Configuración de tópicos, particiones y réplicas.
- Manejo de mensajes fallidos mediante DLT.
- Integración con el dashboard de DigitalFix.

Las mejoras de actualización automática mediante SSE y el dashboard de monitoreo se encuentran en las ramas de desarrollo correspondientes.

## Desarrollo

**Proyecto:** DigitalFix

**Tecnologías principales:** Java 21, Spring Boot, Docker, AWS, RabbitMQ y Apache Kafka.

**Arquitectura:** Microservicios y procesamiento asíncrono de eventos.
