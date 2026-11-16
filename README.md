DigitalFix - Infraestructura
Repositorio de infraestructura y despliegue del proyecto DigitalFix, una plataforma de gestión de servicios técnicos basada en microservicios.

Este repositorio reúne la configuración del backend desplegado en AWS y la infraestructura de eventos con Apache Kafka. Ambos entornos cuentan con archivos Docker Compose independientes.
Integrantes
- Sebastián Ahumada
- Benjamín Gutiérrez
Tecnologías utilizadas
- Cloud: AWS EC2, API Gateway, VPC Link y Network Load Balancer.
- Contenedores: Docker y Docker Compose.
- Backend: Java 21 y Spring Boot.
- Frontend: Angular.
- Identidad y seguridad: Microsoft Entra ID y JWT.
- Persistencia: Oracle Autonomous Database y Oracle Wallet.
- Mensajería: RabbitMQ y Apache Kafka.
- Administración: Kafka UI, Kafka Admin y APIs REST.
- Actualización de interfaz: Server-Sent Events (SSE), en ramas de desarrollo.
Estructura del repositorio
digitalfix-infra/
├── .gitignore
├── README.md
├── infra/
│   └── apps/
│       └── compose.yml
└── kafka/
    ├── docker-compose.yml
    └── scripts/
        └── init-topics.sh
Archivo	Descripción
infra/apps/compose.yml	Despliegue del backend principal de DigitalFix.
kafka/docker-compose.yml	Infraestructura Kafka, ZooKeeper, Kafka UI, Kafka Admin y Analytics.
kafka/scripts/init-topics.sh	Inicialización y configuración de los tópicos Kafka.


Arquitectura del backend en AWS
El backend está organizado en microservicios desplegados mediante Docker Compose en AWS EC2. El tráfico externo pasa por API Gateway y los componentes de red privados antes de llegar al BFF.
Angular / Cliente
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
       +-------------------+
       |                   |
       v                   v
Workorders :8080      Catalog :8082
       |                   |
       +---------+---------+
                 |
                 v
           Oracle Cloud
Componentes principales
Microservicio	Puerto interno	Función
DigitalFix BFF	8081	Centraliza solicitudes, valida JWT y aplica autorización por roles.
Workorders	8080	Gestiona órdenes, clientes y cambios de estado; persiste datos en Oracle.
Catalog	8082	Administra el catálogo técnico y su persistencia en Oracle.


Los servicios se implementan con Spring Boot y Java 21.
Seguridad y control de acceso
La autenticación utiliza Microsoft Entra ID y tokens JWT. API Gateway verifica el token de acceso y el backend aplica las autorizaciones correspondientes. Los microservicios internos no se exponen directamente a Internet.
Recurso	Admin	Supervisor	Cliente
Consultar órdenes	Sí	Sí	Sí
Crear órdenes	Sí	Sí	Sí
Cambiar estado de órdenes	Sí	Sí	No
Gestionar catálogo	Sí	Sí	No


La interfaz puede ocultar opciones según el rol, pero la autorización debe verificarse también en el backend. Las solicitudes sin token o con token inválido se rechazan; los permisos insuficientes producen una respuesta de acceso denegado.
RabbitMQ
RabbitMQ permite el procesamiento de mensajes asociados a operaciones como notificaciones, despacho y reportes. La implementación contempla colas, exchanges, bindings y colas de mensajes fallidos (DLQ).

La integración Kafka descrita a continuación complementa a RabbitMQ; no reemplaza el flujo de mensajería existente.

Archivos de referencia:
- Configuración RabbitMQ.
- Administración RabbitMQ.
- Productor de Workorders para RabbitMQ.
Infraestructura Apache Kafka
Apache Kafka se utiliza para distribuir eventos de órdenes de trabajo y generar métricas de procesamiento. La arquitectura mantiene separados los eventos de negocio y los eventos analíticos.
Flujo de eventos
Angular / DigitalFix
         |
         v
Workorders + Oracle Database
         |
         | Publica un evento JSON
         v
  digitalfix.ordenes.eventos
         |
         v
Kafka Analytics - Consumidor de órdenes
         |
         | Valida y clasifica
         v
  digitalfix.analitica.eventos
         |
         v
Kafka Analytics - Consumidor de métricas
         |
         v
Resumen de métricas (en memoria)
         |
         +-----------------------------+
         |                             |
         v                             v
GET /api/analytics/resumen      SSE /api/analytics/stream
                                       |
                                       v
                                Dashboard Angular
                                (rama de desarrollo)
Workorders publica el evento después de registrar o modificar una orden. Kafka Analytics consume el evento, determina su categoría y publica una métrica en el tópico analítico. Un segundo consumidor registra esa métrica en el resumen.
Servicios de infraestructura
Servicio	Cantidad	Puerto local	Función
ZooKeeper	3	Interno	Coordinación del clúster configurado.
Kafka Brokers	3	19092, 19093, 19094	Almacenamiento y replicación de mensajes.
Kafka UI	1	8088	Inspección visual de brokers, tópicos, mensajes y grupos.
Kafka Admin	1	8090	Administración de tópicos y consumer groups mediante REST.
Kafka Analytics	1	8091	Consumo, clasificación y generación de métricas.


El archivo kafka/docker-compose.yml define estos servicios y la red interna kafka-lab. Los servicios de aplicación utilizan el perfil apps; la inicialización de tópicos utiliza el perfil tools.
Tópicos configurados
Tópico	Propósito
digitalfix.ordenes.eventos	Eventos de creación y cambio de estado de órdenes.
digitalfix.analitica.eventos	Métricas generadas a partir de los eventos de órdenes.
digitalfix.ordenes.eventos.DLT	Eventos de órdenes no procesables.
digitalfix.analitica.eventos.DLT	Eventos de métricas no procesables.


La configuración inicial es la misma para los cuatro tópicos:
Parámetro	Valor
Particiones	3
Factor de replicación	3
Réplicas mínimas sincronizadas	2 (min.insync.replicas)
Retención	604800000 ms (7 días)
Política de limpieza	delete


Los parámetros están definidos en [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh). El script utiliza --if-not-exists para no crear nuevamente tópicos existentes; no cambia las configuraciones de un tópico ya creado.
Productores y consumidores
Productores:
- Workorders publica los eventos de órdenes mediante KafkaWorkOrderEventPublisher.java.
- Kafka Analytics publica métricas mediante el consumidor de órdenes implementado en StreamListeners.java.
Consumidores:
- digitalfix-analytics-workorders: consume el tópico de órdenes y genera métricas.
- digitalfix-analytics-metrics: consume el tópico analítico y actualiza el resumen.
Los consumidores están implementados con @KafkaListener, tienen concurrencia 3 y gestionan sus offsets por registro. Las claves de los mensajes utilizan el identificador de la orden, lo que mantiene la afinidad con una partición mientras no cambie su número.
Manejo de errores
Kafka Analytics valida los mensajes recibidos y utiliza KafkaErrorsConfig.java para gestionar fallas de procesamiento.
- Los errores reintentables siguen una política de reintentos definida en DefaultErrorHandler.
- Las excepciones por payload inválido (IllegalArgumentException) se clasifican como no reintentables.
- Los mensajes que no se pueden procesar se derivan al tópico .DLT correspondiente.
Persistencia de la información
La persistencia se distribuye según la responsabilidad de cada componente:
- Oracle Database: almacena las órdenes de trabajo.
- Kafka: conserva mensajes durante el período configurado de retención.
- Kafka Analytics: mantiene totalEventos, porCategoria y los últimos eventos en memoria.
El resumen de Analytics no usa una base de datos adicional. Sus contadores se reinician al reiniciar el proceso; la existencia de mensajes en Kafka no implica que el resumen se reconstruya automáticamente.
Actualización del dashboard en tiempo real
La extensión de visualización utiliza Server-Sent Events (SSE). Después de registrar una métrica, Analytics envía una notificación a Angular para que consulte los datos actualizados, sin recargar manualmente la página.

Esta extensión se mantiene en ramas de desarrollo independientes:
- Kafka Analytics con SSE — feature/actualizacion-tiempo-real.
- Frontend Live Monitor — feature/dashboard-monitor-en-vivo.
SSE se utiliza para la comunicación Analytics → navegador; Kafka mantiene el transporte de eventos entre microservicios.
Despliegue de Kafka con Docker Compose
Requisitos
- Docker Engine y Docker Compose.
- Acceso a los repositorios digitalfix-infra, ms-digitalfix-kafka-admin y ms-digitalfix-kafka-analytics.
- Puertos disponibles para los servicios publicados por Docker.
Para el flujo completo desde DigitalFix se requieren además Workorders, el frontend y una conexión autorizada a Oracle.
Organización de directorios
El archivo Compose de Kafka usa rutas relativas para construir los microservicios. Los repositorios deben ubicarse como carpetas hermanas dentro de un directorio de trabajo:
DigitalFix/
├── digitalfix-infra/
├── ms-digitalfix-kafka-admin/
├── ms-digitalfix-kafka-analytics/
├── digitalfix-ms-workorders/
└── frontend-digitalfix/
Desde el directorio padre (DigitalFix/), ejecutar los siguientes comandos.
1. Iniciar Kafka, ZooKeeper y Kafka UI
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml up -d
2. Inicializar los tópicos
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
3. Compilar y ejecutar Kafka Admin y Analytics
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
4. Comprobar los contenedores
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps ps
El entorno incluye nueve servicios persistentes: tres ZooKeeper, tres brokers, Kafka UI, Kafka Admin y Kafka Analytics. El servicio kafka-init finaliza después de crear o comprobar los tópicos.
Endpoints de consulta
Servicio	URL local
Kafka UI	http://localhost:8088
Kafka Admin — Tópicos	http://localhost:8090/api/kafka/topics
Kafka Admin — Grupos	http://localhost:8090/api/kafka/groups
Kafka Analytics — Resumen	http://localhost:8091/api/analytics/resumen
SSE — Rama de desarrollo	http://localhost:8091/api/analytics/stream


Nota: el puerto 8090 corresponde a la configuración predeterminada del repositorio. Puede modificarse únicamente el puerto del host si existe un conflicto, manteniendo el puerto 8090 dentro del contenedor.
Revisar registros
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps logs --tail=100 kafka-analytics
Detener los servicios
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps stop
Este comando detiene los servicios sin eliminar los volúmenes de datos. Para conservar los mensajes existentes, evitar el uso de down -v.
Despliegue del backend en AWS
El backend principal utiliza [`infra/apps/compose.yml`](infra/apps/compose.yml) y las variables de entorno correspondientes al servidor.

Desde el directorio padre de digitalfix-infra:

Construir imágenes:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env build
Iniciar servicios:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env up -d
Comprobar contenedores:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env ps
Los servicios principales son digitalfix-bff, digitalfix-workorders y digitalfix-catalog. Esta configuración se administra independientemente del despliegue Kafka.
Variables de entorno y Oracle Wallet
Las credenciales, archivos .env, certificados y Oracle Wallet son información sensible y no se almacenan en GitHub.

Ejemplos de variables utilizadas por el backend:
WORKORDERS_DB_USERNAME
WORKORDERS_DB_PASSWORD
CATALOG_DB_USERNAME
CATALOG_DB_PASSWORD
AZURE_TENANT_ID
AZURE_CLIENT_ID
Oracle Wallet permite la conexión segura de los microservicios con Oracle Cloud Database. En el entorno contenedorizado se monta como volumen de solo lectura, sin incorporarlo a las imágenes Docker.

Los servicios Kafka expuestos en localhost están destinados a un entorno de desarrollo o demostración. Antes de publicarlos en una red externa, deben aplicarse autenticación, autorización y controles de red adecuados.
Verificación funcional
Backend e integración previa
- Acceso a través de API Gateway y validación de JWT.
- Comunicación BFF con Workorders y Catalog.
- Persistencia de órdenes y catálogo en Oracle Database.
- Mensajería operativa mediante RabbitMQ y manejo de mensajes fallidos mediante DLQ.
Integración Kafka
- Inicialización de los cuatro tópicos y verificación de particiones y réplicas.
- Publicación de eventos desde Workorders.
- Consumo y clasificación de eventos mediante Kafka Analytics.
- Generación de métricas y consulta del resumen mediante API REST.
- Consulta de mensajes, tópicos y grupos mediante Kafka UI y Kafka Admin.
- Manejo de mensajes no procesables mediante DLT.
- Actualización automática del dashboard mediante SSE en las ramas de desarrollo indicadas.
Repositorios relacionados
Componente	Repositorio
DigitalFix Infra	digitalfix-infra
Kafka Admin	ms-digitalfix-kafka-admin
Kafka Analytics	ms-digitalfix-kafka-analytics
Workorders	digitalfix-ms-workorders
Frontend	frontend-digitalfix
DigitalFix BFF	digitalfix-ms-bff
Notify	ms-digitalfix-notify
Rabbit Admin	ms-digitalfix-rabbit-admin


Estado de la implementación
La infraestructura documenta dos áreas del proyecto: el backend principal desplegado en AWS y la integración Kafka definida en Docker Compose. El flujo Kafka de eventos, analítica y actualización del dashboard se desarrolla y mantiene en los repositorios enlazados.

Las ramas del frontend y Analytics para SSE se conservan independientes de main hasta su integración definitiva.
