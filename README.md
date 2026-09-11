# DigitalFix - Infraestructura

Infraestructura y despliegue en AWS del proyecto DigitalFix.

## Arquitectura

El backend de DigitalFix utiliza una arquitectura de microservicios desplegada en AWS EC2 mediante Docker y Docker Compose.

Flujo de acceso:

```text
Cliente / Postman
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
Network Load Balancer interno
        |
        v
EC2 - Docker Compose
        |
        +--------------------+
        |                    |
        v                    v
      BFF :8081
        |
        +--------------------+
        |                    |
        v                    v
Workorders :8080       Catalog :8082
        |                    |
        +---------+----------+
                  |
                  v
             Oracle Cloud
````

## Componentes desplegados

### ms-digitalfix-bff

* Spring Boot
* Java 21
* Puerto 8081
* Punto de acceso a Workorders y Catalog
* Valida tokens JWT de Microsoft Entra ID

### ms-digitalfix-workorders

* Spring Boot
* Java 21
* Puerto interno 8080
* Gestión de órdenes de trabajo
* Persistencia en Oracle Cloud

### ms-digitalfix-catalog

* Spring Boot
* Java 21
* Puerto interno 8082
* Gestión del catálogo de servicios
* Persistencia en Oracle Cloud

## Seguridad

El acceso externo al backend se realiza únicamente mediante AWS API Gateway.

La API utiliza un JWT Authorizer configurado con Microsoft Entra ID.

Scope requerido:

```text
access_as_user
```

Comportamiento validado:

```text
Sin token      -> 401 Unauthorized
Token inválido -> 401 Unauthorized
Token válido   -> 200 OK
```

El puerto 8081 del BFF no está abierto directamente a Internet.

El acceso al BFF desde API Gateway se realiza mediante:

```text
API Gateway
→ VPC Link
→ Network Load Balancer interno
→ EC2
→ BFF
```

Workorders y Catalog no publican puertos directamente hacia Internet.

## Docker Compose

El archivo de despliegue se encuentra en:

```text
infra/apps/compose.yml
```

Servicios:

```text
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
```

Todos los servicios utilizan una red Docker interna:

```text
digitalfix-network
```

## Variables de entorno

Las credenciales no se almacenan en GitHub.

El despliegue utiliza variables de entorno para:

```text
WORKORDERS_DB_USERNAME
WORKORDERS_DB_PASSWORD
CATALOG_DB_USERNAME
CATALOG_DB_PASSWORD
AZURE_TENANT_ID
AZURE_CLIENT_ID
```

El archivo `.env` se mantiene únicamente en el servidor y está excluido mediante `.gitignore`.

## Oracle Wallet

Oracle Wallet se utiliza para conectar los microservicios con Oracle Cloud.

El Wallet:

* No se almacena en las imágenes Docker.
* No se almacena en GitHub.
* Se monta como volumen de solo lectura dentro de los contenedores.

```text
/opt/oracle/wallet
```

## Despliegue

Desde el servidor EC2:

```bash
cd ~/digitalfix
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env build
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env up -d
```

Para verificar los contenedores:

```bash
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env ps
```

## Pruebas realizadas

Se verificó correctamente:

* BFF desplegado en AWS EC2.
* Workorders desplegado mediante Docker.
* Catalog desplegado mediante Docker.
* Conexión de Workorders con Oracle Cloud.
* Conexión de Catalog con Oracle Cloud.
* Comunicación BFF → Workorders.
* Comunicación BFF → Catalog.
* API Gateway como punto de entrada.
* Validación JWT con Microsoft Entra ID.
* Rechazo de solicitudes sin token.
* Rechazo de tokens inválidos.
* Acceso con token válido.
* Acceso a Catalog mediante API Gateway.
* Acceso a Workorders mediante API Gateway.
* Bloqueo del acceso directo al BFF desde Internet.
