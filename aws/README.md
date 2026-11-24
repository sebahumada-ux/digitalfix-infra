# DigitalFix - Despliegue completo en AWS

## 1. Objetivo

Documentar el despliegue integrado de DigitalFix en AWS,
incluyendo microservicios, mensajeria, autenticacion,
base de datos, frontend y monitoreo en tiempo real.

## 2. Arquitectura

- AWS EC2 t3.large con Amazon Linux 2023.
- Docker y Docker Compose.
- Oracle Autonomous Database.
- Microsoft Entra ID y autenticacion JWT.
- AWS API Gateway HTTP API.
- VPC Link y Network Load Balancer interno.
- Kafka con 3 brokers y 3 nodos ZooKeeper.
- Kafka UI.
- Kafka Admin y Kafka Analytics.
- RabbitMQ con 2 nodos.
- Rabbit Admin y Notify.
- Microservicios Workorders, Catalog y BFF.
- Frontend Angular con Nginx.
- Caddy como proxy inverso HTTPS.
- Server-Sent Events para monitoreo en tiempo real.

## 3. Repositorios requeridos

Clonar los siguientes repositorios dentro de ~/digitalfix:

- digitalfix-infra
- digitalfix-ms-workorders
- digitalfix-ms-catalog
- digitalfix-ms-bff
- frontend-digitalfix
- ms-digitalfix-kafka-admin
- ms-digitalfix-kafka-analytics
- ms-digitalfix-rabbit-admin
- ms-digitalfix-notify

Utilizar las ramas main correspondientes al despliegue.

## 4. Preparacion

Desde ~/digitalfix:

    cp -n digitalfix-infra/aws/*.yml .
    cp -n digitalfix-infra/aws/.env.example .env
    cp -n digitalfix-infra/aws/Caddyfile.aws.example Caddyfile.aws
    chmod 600 .env Caddyfile.aws

Completar las variables de entorno con credenciales propias.

Descargar el Wallet de Oracle y colocarlo en ~/digitalfix/wallet.

Configurar los dominios publicos y generar los hashes
de autenticacion de Caddy antes de iniciar el proxy.

Los comandos siguientes deben ejecutarse desde ~/digitalfix.

## 5. Despliegue Kafka

    sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml up -d

Esperar que los brokers esten operativos e inicializar los topicos:

    sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init

Desplegar los microservicios Kafka:

    sudo docker compose --project-directory . -f digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics

Configuracion de topicos:

- 3 particiones.
- Factor de replicacion 3.
- Minimo de replicas sincronizadas: 2.
- Retencion de 7 dias.
- Topicos principales y Dead Letter Topics.

## 6. Preparacion del backend

Crear los contenedores y la red del backend sin iniciarlos:

    sudo docker compose --env-file .env -f digitalfix-infra/infra/apps/compose.yml -f backend-kafka.override.yml up --no-start --build

## 7. Despliegue RabbitMQ

    sudo docker compose --env-file .env -f rabbitmq.aws.yml up -d

En una instalacion nueva, esperar que ambos nodos esten operativos
y formar el cluster:

    sudo docker exec digitalfix-rabbitmq-2 rabbitmqctl join_cluster rabbit@rabbitmq-1

Verificar el cluster:

    sudo docker exec digitalfix-rabbitmq-1 rabbitmqctl cluster_status

No repetir la union si el cluster ya esta configurado.

Desplegar Rabbit Admin y Notify:

    sudo docker compose --env-file .env -f rabbitmq.aws.yml -f rabbitmq.apps.yml up -d --build rabbit-admin notify

## 8. Inicio del backend

    sudo docker compose --env-file .env -f digitalfix-infra/infra/apps/compose.yml -f backend-kafka.override.yml up -d

Workorders se comunica con Kafka y RabbitMQ.

Workorders y Catalog utilizan Oracle Autonomous Database.

El BFF centraliza el acceso a los microservicios.

## 9. Configuracion AWS y autenticacion

Configurar:

- Security Groups.
- Network Load Balancer interno.
- Target Group TCP hacia el puerto 8081 del BFF.
- VPC Link.
- API Gateway HTTP API.
- Autorizador JWT de Microsoft Entra ID.
- Scope access_as_user.
- Ruta protegida ANY /{proxy+}.
- Ruta OPTIONS sin autorizacion JWT para CORS.
- Origen CORS correspondiente al frontend.

Registrar la URI HTTPS del frontend en Microsoft Entra ID.

Si cambia API Gateway, actualizar su URL en el frontend
antes de construir la imagen Docker.

## 10. Despliegue frontend

    sudo docker compose -f frontend.aws.yml up -d --build

Nginx sirve Angular y actua como proxy para Kafka Analytics.

No utilizar --remove-orphans, ya que existen otros
contenedores asociados al proyecto Docker Compose.

## 11. Despliegue HTTPS

Generar los hashes bcrypt de las contrasenas:

    sudo docker run --rm -it caddy:2-alpine caddy hash-password --algorithm bcrypt

Reemplazar los marcadores de dominios y hashes en Caddyfile.aws.

Validar la configuracion:

    sudo docker run --rm -v "$PWD/Caddyfile.aws:/etc/caddy/Caddyfile:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile

Iniciar Caddy:

    sudo docker compose -p digitalfix-caddy -f caddy.aws.yml up -d

## 12. Verificacion

    sudo docker ps

    sudo docker stats --no-stream

    curl http://localhost:8090/api/kafka/topics

    curl http://localhost:8091/api/analytics/resumen

    curl -N --max-time 5 http://localhost:8091/api/analytics/stream

Comprobar adicionalmente:

- Inicio de sesion desde el frontend.
- Creacion y asignacion de ordenes de trabajo.
- Publicacion y consumo de eventos Kafka.
- Particiones, offsets y replicacion.
- Consumer groups y Dead Letter Topics.
- Procesamiento de mensajes RabbitMQ.
- Actualizacion del dashboard en tiempo real.

## 13. Seguridad

- No publicar el archivo .env real.
- No publicar el Wallet de Oracle.
- No publicar contrasenas, tokens ni claves privadas.
- No publicar los hashes reales de Caddy.
- Mantener los puertos administrativos restringidos.
- Utilizar HTTPS y autenticacion.
- Restringir CORS al origen autorizado.

## 14. Validacion del despliegue

Durante las pruebas realizadas en AWS se verifico:

- Autenticacion mediante Microsoft Entra ID.
- Creacion de la orden de trabajo 221.
- Asignacion de la orden a un tecnico.
- Publicacion y consumo de eventos Kafka.
- Procesamiento de mensajes EMAIL y DISPATCH.
- Actualizacion de metricas en Kafka Analytics.
- Acceso HTTPS al frontend y herramientas Kafka.

## 15. Consideraciones

El despliegue utiliza una instancia EC2 para alojar
los servicios y los nodos de mensajeria.

La replicacion permite demostrar tolerancia a fallos
de contenedores, pero no garantiza disponibilidad
ante la perdida completa de la instancia EC2.

Si cambia la IP publica de la instancia, actualizar
los dominios, las URI de Entra ID y CORS.

Este repositorio respalda configuraciones y procedimientos,
pero no reemplaza un respaldo de los datos persistentes.

Controlar periodicamente el presupuesto de AWS Academy.

