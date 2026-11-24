# DigitalFix - Infraestructura

Repositorio encargado de la configuración, administración y despliegue de la infraestructura tecnológica del proyecto **DigitalFix**, una plataforma de gestión de servicios técnicos basada en microservicios.

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
- Angular
- Nginx
- Caddy
- HTTPS
- Server-Sent Events (SSE)

## Arquitectura

DigitalFix utiliza una arquitectura de microservicios que permite separar las responsabilidades del sistema y procesar operaciones de manera asíncrona.

La solución contempla los siguientes componentes de infraestructura:

- **Backend AWS:** servicios de negocio, autenticación y persistencia.
- **Infraestructura RabbitMQ:** procesamiento de comandos mediante colas y exchanges.
- **Infraestructura Kafka:** publicación, consumo y procesamiento de eventos.
- **Frontend:** aplicación Angular servida por Nginx, con dashboard de monitoreo en tiempo real.
- **Acceso HTTPS:** Caddy como proxy inverso del frontend y las herramientas Kafka.

Los servicios se ejecutan en contenedores Docker sobre una instancia EC2 `t3.large` con Amazon Linux 2023. Las configuraciones Docker Compose se mantienen separadas y se integran mediante redes Docker compartidas.

```text
Navegador
    |
    | HTTPS
    v
Caddy
    |
    +--> Nginx / Angular --> API Gateway (JWT)
    |                           |
    |                       VPC Link / NLB interno
    |                           |
    |                          BFF
    |                      /        \
    |               Workorders     Catalog
    |                 |   |   \       |
    |                 |   |    +------+--> Oracle Database
    |                 |   |
    |                 |   +--> RabbitMQ --> Notify
    |                 |
    |                 +--> Kafka --> Kafka Analytics
    |                                    |
    |                     Nginx <-- REST / SSE
    |                       |
    |                   Dashboard Angular
    |
    +--> Kafka UI
    +--> Kafka Admin
    +--> Kafka Analytics
```

Las herramientas publicadas mediante Caddy tienen autenticación HTTP básica adicional. Rabbit Admin se mantiene accesible localmente en la instancia.

## Arquitectura del backend

El backend principal utiliza AWS para gestionar el acceso a los microservicios. API Gateway valida el JWT antes de enviar las solicitudes mediante VPC Link a un Network Load Balancer interno, cuyo grupo de destino apunta al puerto `8081` del BFF.

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
- Publicación de comandos hacia RabbitMQ.
- Integración con Notify para el procesamiento asíncrono de operaciones.

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

Configuración del acceso en AWS:

- API Gateway HTTP API con ruta `ANY /{proxy+}` protegida por JWT y scope `access_as_user`.
- Ruta `OPTIONS /{proxy+}` sin autorización JWT para permitir solicitudes preflight CORS.
- NLB interno con destino TCP al puerto `8081` del BFF.
- Security Groups que restringen el acceso al BFF desde el NLB.
- Caddy con HTTPS y autenticación HTTP básica para el frontend y las herramientas Kafka publicadas.
- Puertos administrativos vinculados a localhost o redes internas Docker, sin exposición directa a Internet.

El acceso a las herramientas Kafka y al proxy de Analytics utiliza la protección de Caddy; no corresponde a la misma autorización JWT por roles aplicada al backend de negocio.

La configuración CORS debe restringirse al origen autorizado del frontend. Las URI de redirección de Microsoft Entra ID deben corresponder al dominio HTTPS vigente.

## Oracle Database

DigitalFix utiliza Oracle Autonomous Database como sistema de persistencia para los datos del negocio.

Características:

- Almacenamiento de órdenes de trabajo.
- Persistencia del catálogo técnico.
- Conexión mediante Oracle Wallet.
- Credenciales administradas mediante variables de entorno.
- Pool Hikari ajustado a un máximo de 2 conexiones y un mínimo de 1 conexión inactiva por microservicio de negocio, según la configuración del despliegue AWS.

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

### Arquitectura RabbitMQ

```text
Workorders
    |
    v
RabbitMQ (2 nodos)
    |
    +--> Exchanges direct / topic
              |
              +--> q.cmd.email    --> Notify
              +--> q.cmd.dispatch --> Notify
              +--> q.cmd.report   --> Notify
              |
              +--> Dead Letter Queues

Rabbit Admin --> Administración de RabbitMQ
```

### Recursos de mensajería

| Recurso | Nombre |
|---|---|
| Nodos | `rabbit@rabbitmq-1`, `rabbit@rabbitmq-2` |
| Exchange direct | `cmd.direct` |
| Exchange topic | `cmd.topic` |
| Dead Letter Exchange | `cmd.dead.dlx` |
| Colas principales | `q.cmd.email`, `q.cmd.dispatch`, `q.cmd.report` |
| Colas de mensajes fallidos | `q.cmd.email.dlq`, `q.cmd.dispatch.dlq`, `q.cmd.report.dlq` |

### Rabbit Admin y Notify

Rabbit Admin permite administrar recursos de mensajería mediante API REST. Notify consume los comandos, procesa los mensajes y envía ACK según el flujo configurado.

En AWS se verificó el procesamiento de comandos EMAIL y DISPATCH asociados a la asignación de una orden de trabajo. Esta prueba acredita el consumo y confirmación de los mensajes, no la entrega de un correo a un proveedor externo.

Los archivos `aws/rabbitmq.aws.yml` y `aws/rabbitmq.apps.yml` contienen las configuraciones de los nodos y microservicios RabbitMQ.

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

El dashboard incorpora notificaciones SSE para actualizar automáticamente la información mostrada. La integración fue fusionada en `main` y validada en el despliegue AWS.

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
- Notificaciones SSE para actualizar el dashboard en tiempo real.

Puerto del microservicio:

`8091`

### Endpoints principales

```http
GET /api/analytics/resumen
GET /api/analytics/stream
```

El endpoint `/stream` corresponde a la implementación SSE integrada en `main`. Nginx reenvía las solicitudes `/api/analytics/` hacia Kafka Analytics, sin buffering para permitir el flujo de eventos.

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

## Frontend DigitalFix y dashboard

El frontend Angular permite acceder al catálogo, gestionar las órdenes de trabajo y consultar el dashboard de monitoreo.

Características:

- Autenticación de usuarios con Microsoft Entra ID mediante MSAL.
- Consumo de las rutas del backend a través de API Gateway con JWT.
- Consulta del resumen de Kafka Analytics mediante REST.
- Actualización de métricas mediante Server-Sent Events (SSE).
- Nginx para servir Angular y reenviar las solicitudes hacia Kafka Analytics.
- Caddy para terminación HTTPS y autenticación HTTP básica adicional.

Las mejoras del dashboard y Kafka Analytics se encuentran integradas en las ramas `main` de sus respectivos repositorios.

## Estructura del repositorio

```text
digitalfix-infra/
├── README.md
├── .gitignore
├── infra/
│   └── apps/
│       └── compose.yml
├── kafka/
│   ├── docker-compose.yml
│   └── scripts/
│       └── init-topics.sh
└── aws/
    ├── README.md
    ├── .env.example
    ├── Caddyfile.aws.example
    ├── backend-kafka.override.yml
    ├── rabbitmq.aws.yml
    ├── rabbitmq.apps.yml
    ├── frontend.aws.yml
    └── caddy.aws.yml
```

### Archivos principales

| Archivo | Función |
|---|---|
| `infra/apps/compose.yml` | Configuración del backend principal. |
| `kafka/docker-compose.yml` | Clúster Kafka, ZooKeeper, Kafka UI y microservicios Kafka. |
| `kafka/scripts/init-topics.sh` | Inicialización y verificación de tópicos Kafka. |
| `aws/backend-kafka.override.yml` | Integración de Workorders con Kafka y RabbitMQ; ajuste de conexiones Oracle. |
| `aws/rabbitmq.aws.yml` | Despliegue de los dos nodos RabbitMQ. |
| `aws/rabbitmq.apps.yml` | Despliegue de Rabbit Admin y Notify. |
| `aws/frontend.aws.yml` | Despliegue Angular y Nginx. |
| `aws/caddy.aws.yml` | Despliegue del proxy inverso Caddy. |
| `aws/Caddyfile.aws.example` | Plantilla de dominios, rutas y autenticación HTTPS. |
| `aws/.env.example` | Plantilla de variables de entorno sin credenciales. |
| `aws/README.md` | Guía de despliegue integrado y recuperación. |

## Docker Compose

Los repositorios deben encontrarse al mismo nivel dentro de un directorio de trabajo. Para el despliegue integrado en AWS se utiliza la siguiente estructura:

```text
DigitalFix/
├── digitalfix-infra/
├── digitalfix-ms-workorders/
├── digitalfix-ms-catalog/
├── digitalfix-ms-bff/
├── frontend-digitalfix/
├── ms-digitalfix-kafka-admin/
├── ms-digitalfix-kafka-analytics/
├── ms-digitalfix-rabbit-admin/
├── ms-digitalfix-notify/
├── wallet/                       # Privado
├── .env                          # Privado
├── backend-kafka.override.yml
├── rabbitmq.aws.yml
├── rabbitmq.apps.yml
├── frontend.aws.yml
├── caddy.aws.yml
└── Caddyfile.aws                 # Privado
```

Las configuraciones de `aws/` se copian al directorio padre para conservar las rutas relativas utilizadas por Docker Compose. Los archivos privados se preparan localmente a partir de las plantillas.

Los servicios Kafka utilizan la red `digitalfix-kafka-ev3_kafka-lab`. El backend y RabbitMQ utilizan `digitalfix_digitalfix-network`. Workorders participa en ambas redes para acceder a los sistemas de mensajería.

## Despliegue de Kafka

Los siguientes comandos se ejecutan desde el directorio padre que contiene los repositorios. Estos ejemplos permiten iniciar Kafka de manera independiente en un entorno local. En AWS se utiliza `sudo docker` cuando corresponde y se sigue el orden de la guía de despliegue integrado.

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

### Acceso local o desde la instancia EC2

| Servicio | Dirección o puerto |
|---|---|
| Kafka UI | `http://localhost:8088` |
| Kafka Admin | `http://localhost:8090/api/kafka/topics` |
| Kafka Analytics | `http://localhost:8091/api/analytics/resumen` |
| Kafka Analytics SSE | `http://localhost:8091/api/analytics/stream` |
| RabbitMQ Management | `http://localhost:15672` |
| Rabbit Admin | `http://localhost:8084` |
| Frontend | `http://localhost:8085` |
| BFF | `8081` (acceso protegido; en AWS, desde el NLB) |

En AWS, `localhost` corresponde a la propia EC2, no al computador del usuario. Los puertos internos de los brokers y microservicios no deben exponerse directamente a Internet.

### Acceso HTTPS en AWS

Caddy publica el frontend y las herramientas Kafka mediante dominios configurados para la IP pública vigente. Las siguientes direcciones son ejemplos de su estructura, no enlaces activos permanentes:

| Servicio | Dirección de referencia |
|---|---|
| Frontend | `https://DOMINIO_FRONTEND` |
| Kafka UI | `https://DOMINIO_KAFKA` |
| Kafka Admin | `https://DOMINIO_ADMIN/api/kafka/topics` |
| Kafka Analytics | `https://DOMINIO_ANALYTICS/api/analytics/resumen` |

El acceso requiere las credenciales de autenticación configuradas localmente en Caddy.

## Despliegue del backend AWS

El procedimiento completo, incluidos Kafka, RabbitMQ, Oracle, frontend y HTTPS, se encuentra en [aws/README.md](aws/README.md). Los comandos siguientes corresponden al despliegue integrado y deben ejecutarse desde `~/digitalfix` en la EC2, una vez preparados los repositorios, el Wallet y las variables de entorno.

### Preparar configuraciones

```bash
cp -n digitalfix-infra/aws/*.yml .
cp -n digitalfix-infra/aws/.env.example .env
cp -n digitalfix-infra/aws/Caddyfile.aws.example Caddyfile.aws
chmod 600 .env Caddyfile.aws
```

Completar las credenciales del archivo `.env`, el Wallet de Oracle y los dominios y hashes de Caddy. No reemplazar configuraciones privadas que ya estén en uso.

### Iniciar Kafka

```bash
sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml up -d
sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
```

Esperar que los brokers estén operativos antes de inicializar los tópicos.

### Preparar backend y red

```bash
sudo docker compose --env-file .env -f digitalfix-infra/infra/apps/compose.yml -f backend-kafka.override.yml up --no-start --build
```

### Iniciar RabbitMQ

```bash
sudo docker compose --env-file .env -f rabbitmq.aws.yml up -d
```

Solo para una instalación nueva, esperar a que los dos nodos estén operativos y formar el clúster:

```bash
sudo docker exec digitalfix-rabbitmq-2 rabbitmqctl join_cluster rabbit@rabbitmq-1
sudo docker exec digitalfix-rabbitmq-1 rabbitmqctl cluster_status
```

No repetir la unión en un clúster existente. Iniciar los microservicios de mensajería:

```bash
sudo docker compose --env-file .env -f rabbitmq.aws.yml -f rabbitmq.apps.yml up -d --build rabbit-admin notify
```

### Iniciar backend

```bash
sudo docker compose --env-file .env -f digitalfix-infra/infra/apps/compose.yml -f backend-kafka.override.yml up -d
```

Configurar el NLB interno, VPC Link, API Gateway HTTP API, JWT Authorizer, CORS y Microsoft Entra ID según la guía AWS. Si cambia la URL de API Gateway, actualizar las referencias correspondientes en el frontend antes de construir la imagen.

### Iniciar frontend y HTTPS

```bash
sudo docker compose -f frontend.aws.yml up -d --build
```

No utilizar `--remove-orphans`, ya que se pueden eliminar contenedores de otros componentes del proyecto.

Una vez completado `Caddyfile.aws` con los dominios y hashes de autenticación propios, validar e iniciar Caddy:

```bash
sudo docker run --rm -v "$PWD/Caddyfile.aws:/etc/caddy/Caddyfile:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
sudo docker compose -p digitalfix-caddy -f caddy.aws.yml up -d
```

### Verificar el despliegue

```bash
sudo docker ps
sudo docker stats --no-stream
sudo docker exec digitalfix-rabbitmq-1 rabbitmqctl cluster_status
curl http://localhost:8090/api/kafka/topics
curl http://localhost:8091/api/analytics/resumen
curl -N --max-time 5 http://localhost:8091/api/analytics/stream
```

La consulta SSE mantiene una conexión abierta; el límite de cinco segundos finaliza la prueba de `curl` sin indicar necesariamente un fallo del servicio.

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
RABBITMQ_USERNAME
RABBITMQ_PASSWORD
RABBITMQ_ERLANG_COOKIE
```

Las variables del archivo `.env` se encuentran en [`aws/.env.example`](aws/.env.example). `KAFKA_ENABLED` y `KAFKA_BOOTSTRAP_SERVERS` se configuran mediante `aws/backend-kafka.override.yml`.

Los archivos `.env`, contraseñas, tokens, hashes reales de Caddy y Oracle Wallet deben mantenerse fuera del control de versiones. El `.gitignore` incluye reglas para excluir estos archivos privados; las plantillas `.example` sí se versionan.

## Repositorios relacionados

| Repositorio | Función |
|---|---|
| [digitalfix-infra](https://github.com/sebahumada-ux/digitalfix-infra) | Infraestructura y documentación. |
| [digitalfix-ms-workorders](https://github.com/sebahumada-ux/digitalfix-ms-workorders) | Gestión de órdenes. |
| [digitalfix-ms-catalog](https://github.com/sebahumada-ux/digitalfix-ms-catalog) | Catálogo de servicios. |
| [digitalfix-ms-bff](https://github.com/sebahumada-ux/digitalfix-ms-bff) | Acceso centralizado al backend. |
| [frontend-digitalfix](https://github.com/sebahumada-ux/frontend-digitalfix) | Frontend Angular y dashboard. |
| [ms-digitalfix-rabbit-admin](https://github.com/sebahumada-ux/ms-digitalfix-rabbit-admin) | Administración RabbitMQ. |
| [ms-digitalfix-notify](https://github.com/sebahumada-ux/ms-digitalfix-notify) | Consumo de comandos RabbitMQ. |
| [ms-digitalfix-kafka-admin](https://github.com/sebahumada-ux/ms-digitalfix-kafka-admin) | Administración Kafka. |
| [ms-digitalfix-kafka-analytics](https://github.com/sebahumada-ux/ms-digitalfix-kafka-analytics) | Procesamiento de eventos y métricas SSE. |

## Estado del proyecto

La infraestructura de DigitalFix contempla:

- Backend de microservicios en AWS.
- Autenticación mediante Microsoft Entra ID y autorización JWT por roles.
- Persistencia en Oracle Autonomous Database.
- Clúster RabbitMQ de dos nodos, exchanges, colas y consumidores.
- Clúster Kafka de tres brokers y tres nodos ZooKeeper.
- Administración REST mediante Rabbit Admin y Kafka Admin.
- Procesamiento de eventos mediante Kafka Analytics.
- Configuración de tópicos, particiones, réplicas y consumer groups.
- Manejo de mensajes fallidos mediante DLQ y DLT.
- Frontend Angular, Nginx y acceso HTTPS mediante Caddy.
- Dashboard de monitoreo en tiempo real mediante SSE.
