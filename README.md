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
