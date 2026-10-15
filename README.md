# DigitalFix - Infraestructura

Repositorio de infraestructura y despliegue en AWS del proyecto **DigitalFix**.

Este repositorio contiene la configuración utilizada para desplegar los servicios backend de DigitalFix mediante Docker y Docker Compose sobre una instancia AWS EC2.

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
- Microsoft Entra ID
- JWT
- Oracle Cloud Database
- Oracle Wallet
- Spring Boot
- Java 21

## Arquitectura

El backend de DigitalFix utiliza una arquitectura de microservicios desplegada en AWS.

Flujo principal:

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
BFF :8081
   /       \
  v         v
Workorders  Catalog
  :8080      :8082
     \       /
      v     v
    Oracle Cloud
````

## Componentes desplegados

### DigitalFix BFF

Servicio encargado de centralizar las solicitudes provenientes del frontend.

Características:

* Spring Boot
* Java 21
* Puerto interno 8081
* Comunicación con Workorders
* Comunicación con Catalog
* Validación de JWT
* Autorización por roles

Nombre del contenedor:

```text
digitalfix-bff
```

### Workorders

Microservicio encargado de la gestión de órdenes de trabajo.

Características:

* Spring Boot
* Java 21
* Puerto interno 8080
* Persistencia en Oracle Database
* Creación y consulta de órdenes
* Actualización de estados
* Validación de transiciones

Nombre del contenedor:

```text
digitalfix-workorders
```

### Catalog

Microservicio encargado de la gestión del catálogo técnico.

Características:

* Spring Boot
* Java 21
* Puerto interno 8082
* Persistencia en Oracle Database
* Consulta de servicios
* Creación y actualización de servicios

Nombre del contenedor:

```text
digitalfix-catalog
```

## Seguridad

El backend no se expone directamente a Internet.

El acceso externo se realiza mediante:

```text
Internet
→ AWS API Gateway
→ JWT Authorizer
→ VPC Link
→ Network Load Balancer
→ EC2
→ BFF
```

AWS API Gateway utiliza un JWT Authorizer configurado con Microsoft Entra ID.

Scope utilizado:

```text
access_as_user
```

Comportamiento validado:

```text
Sin token      → 401 Unauthorized
Token inválido → 401 Unauthorized
Token válido   → Acceso permitido según rol
```

El BFF realiza una segunda validación de seguridad y autorización por roles.

Roles utilizados:

```text
Admin
Supervisor
Cliente
```

## Control de acceso

Permisos implementados:

| Recurso                     | Admin | Supervisor | Cliente |
| --------------------------- | ----- | ---------- | ------- |
| Workorders - consultar      | Sí    | Sí         | Sí      |
| Workorders - crear          | Sí    | Sí         | Sí      |
| Workorders - cambiar estado | Sí    | Sí         | No      |
| Catalog                     | Sí    | Sí         | No      |

El frontend aplica restricciones de navegación, pero la autorización real también se valida en el backend.

## API Gateway

AWS API Gateway funciona como punto de entrada al backend.

Flujo:

```text
Frontend
→ API Gateway
→ JWT Authorizer
→ VPC Link
→ Network Load Balancer
→ BFF
```

Las rutas protegidas requieren un token JWT válido.

Las solicitudes `OPTIONS` utilizadas para CORS se permiten sin autenticación.

## Network Load Balancer

Se utiliza un Network Load Balancer interno para conectar API Gateway con el BFF desplegado en EC2.

El NLB recibe las solicitudes desde el VPC Link y las dirige hacia el servicio BFF.

## VPC Link

El VPC Link permite que API Gateway acceda de forma privada a los recursos internos de la VPC.

Esto evita exponer directamente los puertos internos de los microservicios.

## AWS EC2

Los servicios backend se ejecutan dentro de una instancia AWS EC2 mediante Docker.

Servicios ejecutados:

```text
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
```

Todos los servicios se encuentran conectados mediante una red Docker interna.

## Docker Compose

El archivo principal de despliegue se encuentra en:

```text
infra/apps/compose.yml
```

La configuración levanta los siguientes servicios:

```text
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
```

Los contenedores utilizan la red:

```text
digitalfix-network
```

## Estructura del repositorio

```text
digitalfix-infra/
│
├── .gitignore
├── README.md
│
└── infra/
    └── apps/
        └── compose.yml
```

## Variables de entorno

Las credenciales y configuraciones sensibles no se almacenan directamente en GitHub.

Variables utilizadas:

```text
WORKORDERS_DB_USERNAME
WORKORDERS_DB_PASSWORD
CATALOG_DB_USERNAME
CATALOG_DB_PASSWORD
AZURE_TENANT_ID
AZURE_CLIENT_ID
```

El archivo:

```text
.env
```

permanece únicamente en el servidor.

## Archivos excluidos

El archivo `.gitignore` evita subir información sensible.

Se excluyen:

```text
.env
*.env

wallet/
**/wallet/

*.pem
*.p12
*.jks
*.sso

target/
.idea/
*.iml
```

## Oracle Database

Los microservicios Workorders y Catalog utilizan Oracle Database para persistencia.

Cada dominio utiliza su propia configuración de conexión.

Las credenciales se entregan mediante variables de entorno.

## Oracle Wallet

Oracle Wallet se utiliza para realizar la conexión segura con Oracle Cloud Database.

El wallet:

* No se almacena en GitHub.
* No se incluye dentro de las imágenes Docker.
* Se monta como volumen de solo lectura.

Ruta utilizada dentro de los contenedores:

```text
/opt/oracle/wallet
```

## Despliegue

Desde la instancia EC2:

```bash
cd ~/digitalfix
```

Construir las imágenes:

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  build
```

Levantar los servicios:

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  up -d
```

## Verificación

Para comprobar el estado de los contenedores:

```bash
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  ps
```

También puede utilizarse:

```bash
docker ps
```

Contenedores esperados:

```text
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
```

## Logs

Para revisar el BFF:

```bash
docker logs --tail 25 digitalfix-bff
```

Para Workorders:

```bash
docker logs --tail 25 digitalfix-workorders
```

Para Catalog:

```bash
docker logs --tail 25 digitalfix-catalog
```

## Pruebas realizadas

Se validaron las siguientes funcionalidades:

* BFF desplegado en AWS EC2.
* Workorders desplegado mediante Docker.
* Catalog desplegado mediante Docker.
* Conexión de Workorders con Oracle Database.
* Conexión de Catalog con Oracle Database.
* Comunicación BFF → Workorders.
* Comunicación BFF → Catalog.
* API Gateway funcionando como punto de entrada.
* JWT Authorizer integrado con Microsoft Entra ID.
* Solicitud sin token → 401.
* Token inválido → 401.
* Token válido → acceso permitido.
* Acceso de Admin a Catalog.
* Acceso de Cliente a Workorders.
* Acceso de Cliente a Catalog → 403.
* CORS configurado para el frontend.
* Acceso directo al BFF desde Internet bloqueado.
* Contenedores funcionando correctamente en EC2.

## Flujo completo de una solicitud

```text
Usuario
   |
   v
Angular
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
VPC Link
   |
   v
Network Load Balancer
   |
   v
BFF
   |
   +-------------------+
   |                   |
   v                   v
Workorders          Catalog
   |                   |
   +---------+---------+
             |
             v
        Oracle Database
```

## Estado del proyecto

Actualmente se encuentran implementados y validados:

* Arquitectura de microservicios.
* API Gateway.
* JWT Authorizer.
* Integración con Microsoft Entra ID.
* VPC Link.
* Network Load Balancer.
* AWS EC2.
* Docker.
* Docker Compose.
* BFF.
* Workorders.
* Catalog.
* Oracle Database.
* Oracle Wallet.
* Variables de entorno.
* Restricción de acceso externo directo a los microservicios.

## Matriz de funcionalidades

La matriz reúne el alcance de DigitalFix para la Evaluación Parcial 2, indicando el estado de cada funcionalidad, su componente responsable y la evidencia para verificarla.

| ID | Funcionalidad | Estado | Componente responsable | Evidencia verificable |
| --- | --- | --- | --- | --- |
| F01 | Frontend desplegado en AWS con HTTPS | Implementada | Angular, Nginx y Caddy | [Dockerfile del frontend][frontend-docker], [configuración Nginx][frontend-nginx] y acceso al sitio durante la demostración. |
| F02 | Autenticación con Microsoft Entra ID y utilización de JWT | Implementada | Angular MSAL, Entra ID y BFF | [Configuración MSAL][frontend-auth] y [validación JWT y roles del BFF][bff-security]. Pruebas de acceso autorizado y rechazo de solicitudes inválidas. |
| F03 | Consumo del backend mediante API Gateway | Implementada | Frontend, API Gateway y BFF | [Configuración del consumo de API Gateway][frontend-auth]. Verificación de rutas, authorizer e integraciones en AWS. |
| F04 | Backend desplegado e integrado con Oracle Database | Implementada | BFF, Workorders y Catalog | [Docker Compose del backend][backend-compose], configuración de persistencia y consulta de datos desde el frontend. |
| F05 | Clúster RabbitMQ de dos nodos | Implementada | rabbitmq-1 y rabbitmq-2 | Verificación en AWS mediante `docker ps` y `docker exec rabbitmq-1 rabbitmqctl cluster_status`. |
| F06 | Tres colas principales y sus respectivas DLQ | Implementada | RabbitMQ y Notify | [Declaración de colas y DLQ][rabbit-config]. Consulta de colas y prueba de mensaje inválido enviado a `q.cmd.email.dlq`. |
| F07 | Exchanges direct y topic con sus bindings | Implementada | Configuración RabbitMQ de Workorders y Notify | [RabbitMqConfig.java][rabbit-config], con `cmd.direct`, `cmd.topic`, `cmd.dead.dlx` y sus claves de enrutamiento. |
| F08 | Administración de colas, exchanges y bindings mediante API REST | Implementada | Rabbit Admin | [RabbitAdminController.java][rabbit-controller] y [DTO de entrada][rabbit-dtos]. Pruebas de creación y eliminación mediante `/api/rabbit`. |
| F09 | Flujo completo de eventos con confirmación y manejo de errores | Implementada | Workorders, RabbitMQ y Notify | [Productor de eventos][event-publisher] y [consumidores por dominio][notify-listeners]. Cambio de estado de una orden, procesamiento con ACK y rechazo con NACK sin reencolar hacia DLQ. |

### Resultado del alcance

Las nueve funcionalidades de esta matriz se declaran implementadas:

**Porcentaje de implementación declarado: 9 / 9 × 100 = 100%.**

Durante la presentación se demuestra su funcionamiento. El porcentaje evaluado depende de las funcionalidades efectivamente demostradas.

### Alcance del procesamiento de Notify

Notify valida los eventos de Email, Dispatch y Report y registra su procesamiento en logs. Esta implementación demuestra el flujo de mensajería, el ACK manual y el tratamiento de errores mediante DLQ.

### Evidencias de infraestructura

El archivo `infra/apps/compose.yml` publicado en este repositorio corresponde al backend base: BFF, Workorders y Catalog.

La configuración Compose utilizada para el clúster RabbitMQ y los servicios adicionales desplegados en AWS debe incorporarse al repositorio para permitir reproducir el ambiente completo.

[frontend-docker]: https://github.com/sebahumada-ux/frontend-digitalfix/blob/main/Dockerfile
[frontend-nginx]: https://github.com/sebahumada-ux/frontend-digitalfix/blob/main/nginx.conf
[frontend-auth]: https://github.com/sebahumada-ux/frontend-digitalfix/blob/main/src/app/app.config.ts
[bff-security]: https://github.com/sebahumada-ux/digitalfix-ms-bff/blob/main/src/main/java/cl/duoc/digitalfix/bff/config/SecurityConfig.java
[backend-compose]: https://github.com/sebahumada-ux/digitalfix-infra/blob/main/infra/apps/compose.yml
[rabbit-config]: https://github.com/sebahumada-ux/ms-digitalfix-notify/blob/main/src/main/java/ms_digitalfix_notify/config/RabbitMqConfig.java
[rabbit-controller]: https://github.com/sebahumada-ux/ms-digitalfix-rabbit-admin/blob/main/src/main/java/ms_digitalfix_rabbit_admin/controller/RabbitAdminController.java
[rabbit-dtos]: https://github.com/sebahumada-ux/ms-digitalfix-rabbit-admin/tree/main/src/main/java/ms_digitalfix_rabbit_admin/dto
[event-publisher]: https://github.com/sebahumada-ux/digitalfix-ms-workorders/blob/main/src/main/java/cl/duoc/digitalfix/workorders/messaging/WorkOrderEventPublisher.java
[notify-listeners]: https://github.com/sebahumada-ux/ms-digitalfix-notify/tree/main/src/main/java/ms_digitalfix_notify/listener
