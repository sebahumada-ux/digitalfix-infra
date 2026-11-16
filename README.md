DigitalFix — Infraestructura
Infraestructura y configuración de despliegue de DigitalFix, una plataforma de gestión de servicios técnicos basada en microservicios. El repositorio centraliza la configuración del backend en AWS, junto con una arquitectura de mensajería con Apache Kafka, implementada mediante Docker Compose.

La solución contempla dos entornos independientes: la infraestructura de servicios de negocio en AWS y el entorno de integración Kafka. La existencia de archivos para ambos entornos no implica que el clúster Kafka esté desplegado en AWS.
Equipo
- Sebastián Ahumada
- Benjamín Gutiérrez
Tecnologías
Categoría	Tecnologías
Infraestructura cloud	AWS EC2, API Gateway, VPC Link, Network Load Balancer
Contenedores	Docker, Docker Compose
Backend	Java 21, Spring Boot
Frontend	Angular
Identidad y seguridad	Microsoft Entra ID, OAuth 2.0, JWT
Persistencia	Oracle Autonomous Database, Oracle Wallet
Mensajería	RabbitMQ, Apache Kafka, ZooKeeper
Observabilidad y administración	Kafka UI, API REST de Kafka Admin
Actualización de interfaz	Server-Sent Events (SSE), disponible en ramas de desarrollo


1. Organización del repositorio
digitalfix-infra/
├── README.md
├── .gitignore
├── infra/
│   └── apps/
│       └── compose.yml
└── kafka/
    ├── docker-compose.yml
    └── scripts/
        └── init-topics.sh
Ruta	Responsabilidad
infra/apps/compose.yml	Definición de los servicios backend asociados al entorno AWS
kafka/docker-compose.yml	Definición del clúster Kafka, ZooKeeper, Kafka UI y microservicios Kafka
kafka/scripts/init-topics.sh	Creación y configuración inicial de los tópicos Kafka


2. Arquitectura de servicios en AWS
La arquitectura del backend utiliza AWS API Gateway como punto de entrada, autenticación con Microsoft Entra ID y comunicación privada hacia los servicios desplegados en EC2.
                     Angular
                        |
                        v
                  API Gateway
                        |
               JWT Authorizer
                 Entra ID
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
                      BFF
                   /       \
                  v         v
             Workorders   Catalog
                  \         /
                   v       v
               Oracle Database
Componentes
Servicio	Puerto interno	Función
DigitalFix BFF	8081	Centraliza solicitudes, verifica JWT y aplica autorización por roles
Workorders	8080	Gestiona órdenes de trabajo, transiciones de estado y persistencia
Catalog	8082	Administra el catálogo de servicios técnicos


Los servicios backend utilizan Java 21 y Spring Boot. Workorders y Catalog persisten sus entidades en Oracle mediante sus respectivas configuraciones de conexión.
Autenticación y autorización
El acceso a los recursos protegidos se gestiona mediante tokens JWT emitidos por Microsoft Entra ID. AWS API Gateway valida los tokens de entrada y el backend aplica las reglas de autorización correspondientes.

Roles contemplados: Admin, Supervisor y Cliente.
Operación	Admin	Supervisor	Cliente
Consultar órdenes	Sí	Sí	Sí
Crear órdenes	Sí	Sí	Sí
Cambiar estado de órdenes	Sí	Sí	No
Gestionar catálogo	Sí	Sí	No


El frontend controla la visibilidad de sus opciones, pero la autorización efectiva se aplica en el backend. Los servicios internos no requieren exposición directa a Internet para ser consumidos a través de API Gateway.
Integración con RabbitMQ
La arquitectura incorpora RabbitMQ para mensajería relacionada con procesos operativos, como notificaciones, despacho y generación de reportes. Las colas, los exchanges, los bindings y sus respectivos mecanismos de mensajes fallidos pertenecen a esta integración.

Kafka complementa RabbitMQ: se utiliza para transportar eventos de órdenes y producir información analítica, sin reemplazar las integraciones de mensajería previamente implementadas.

Referencias del código:
- Configuración RabbitMQ
- Administración RabbitMQ
- Productor Workorders para RabbitMQ
3. Arquitectura Apache Kafka
La integración Kafka permite publicar, consumir y procesar eventos de órdenes de trabajo de manera desacoplada, mediante dos tópicos principales y sus respectivos tópicos de mensajes fallidos (Dead Letter Topics).
        Angular / DigitalFix
                 |
                 v
       Workorders + Oracle
                 |
          Productor Kafka
                 |
                 v
    digitalfix.ordenes.eventos
                 |
                 v
       Kafka Analytics
       Consumer de órdenes
       Validación y clasificación
                 |
          Productor Kafka
                 |
                 v
   digitalfix.analitica.eventos
                 |
                 v
       Kafka Analytics
       Consumer de métricas
                 |
           Resumen en memoria
                 |
       +---------+----------+
       |                    |
       v                    v
  API REST              SSE (rama de
  /resumen              desarrollo)
                            |
                            v
                      Dashboard Angular
Servicios Kafka
Componente	Cantidad	Puerto del host	Función
ZooKeeper	3	Interno	Coordinación de la arquitectura Kafka configurada
Brokers Kafka	3	19092, 19093, 19094	Recepción, almacenamiento y replicación de eventos
Kafka UI	1	8088	Inspección de brokers, tópicos, particiones, mensajes y grupos
Kafka Admin	1	8090	Administración de tópicos y grupos mediante API REST
Kafka Analytics	1	8091	Consumo, clasificación y publicación de métricas


Kafka Admin y Kafka Analytics se ejecutan con el perfil apps de Docker Compose. El servicio kafka-init, perteneciente al perfil tools, inicializa los tópicos y finaliza al completar su tarea.
Tópicos
Tópico	Propósito
digitalfix.ordenes.eventos	Eventos asociados a la creación y modificación de órdenes
digitalfix.analitica.eventos	Métricas derivadas de los eventos de órdenes
digitalfix.ordenes.eventos.DLT	Eventos de órdenes que no pudieron procesarse correctamente
digitalfix.analitica.eventos.DLT	Eventos de métricas que no pudieron procesarse correctamente


Los cuatro tópicos utilizan la siguiente configuración inicial:
Parámetro	Valor
Particiones	3
Factor de replicación	3
Réplicas mínimas sincronizadas	min.insync.replicas=2
Retención	604800000 ms (7 días)
Política de limpieza	delete


La configuración se aplica desde [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh). El script utiliza --if-not-exists; por tanto, crea tópicos faltantes, pero no modifica automáticamente la configuración de los ya existentes.
Producción y consumo de eventos
Workorders publica eventos JSON al crear una orden o modificar su estado. La clave (key) del mensaje corresponde al identificador de la orden, lo que permite mantener la afinidad de sus eventos con una partición mientras no cambie el número de particiones.

Kafka Analytics implementa dos consumidores en StreamListeners.java:
1. Consume eventos de digitalfix.ordenes.eventos, valida el contenido y publica una métrica en digitalfix.analitica.eventos.
2. Consume las métricas publicadas y actualiza los contadores y la colección de eventos recientes.
Las reglas de clasificación están separadas en ClasificadorOrden.java. Las métricas pueden incluir las categorías CAMBIO_ESTADO, ORDEN_ASIGNADA, ORDEN_CERRADA y ORDEN_CANCELADA, según el estado recibido.
Consumer groups
Grupo	Tópico consumido	Responsabilidad
digitalfix-analytics-workorders	digitalfix.ordenes.eventos	Validar órdenes y generar métricas
digitalfix-analytics-metrics	digitalfix.analitica.eventos	Registrar métricas en el resumen


Los listeners utilizan concurrencia 3, confirmación por registro (ack-mode: record) y enable-auto-commit: false. El grupo y los offsets permiten coordinar la distribución del procesamiento y consultar el atraso (lag) de cada partición.
Manejo de errores y DLT
KafkaErrorsConfig.java define el tratamiento de excepciones durante el consumo, incluido el registro de errores y el envío de mensajes no procesables al tópico .DLT correspondiente.
- Los errores reintentables utilizan una política de reintentos con FixedBackOff.
- Las excepciones IllegalArgumentException, utilizadas para entradas inválidas, se consideran no reintentables.
- Los eventos derivados al DLT conservan la partición de origen.
Persistencia y alcance de las métricas
Las órdenes de trabajo se almacenan en Oracle. Kafka conserva los mensajes de acuerdo con la retención configurada. El resumen de Analytics (totalEventos, porCategoria y recientes) se administra en memoria, mediante ResumenService.java, sin una base de datos analítica adicional.

En consecuencia, los contadores se reinician con el proceso de Analytics. La retención en Kafka no implica una reconstrucción automática del resumen en memoria.
4. Actualización del dashboard mediante SSE
La arquitectura dispone de una extensión para mostrar cambios en la interfaz sin recargar la página. Server-Sent Events (SSE) notifica al navegador después de registrar una nueva métrica. Angular recibe el aviso y vuelve a consultar las APIs de Workorders y Analytics.

Esta extensión se mantiene en ramas de desarrollo independientes y no forma parte del main de esos repositorios:
- Kafka Analytics — feature/actualizacion-tiempo-real
- Frontend DigitalFix — feature/dashboard-monitor-en-vivo
El endpoint SSE se expone como /api/analytics/stream en la versión de Analytics de esa rama. Esta funcionalidad está orientada a la visualización de cambios; no sustituye el transporte de eventos entre microservicios realizado por Kafka.
5. Despliegue del entorno Kafka
Requisitos
- Docker Engine y Docker Compose.
- Acceso a los repositorios de Kafka Admin y Kafka Analytics.
- Puertos del host disponibles para Kafka y los servicios auxiliares.
- Java 21 y Node.js compatible con Angular para ejecutar Workorders y el frontend fuera de Docker, cuando corresponda.
- Conexión autorizada a Oracle y Wallet configurada para ejecutar Workorders.
Organización del directorio de trabajo
El archivo Compose utiliza rutas relativas para construir las imágenes de Kafka Admin y Kafka Analytics. Se requiere disponer los repositorios en un mismo directorio padre:
DigitalFix/
├── digitalfix-infra/
├── ms-digitalfix-kafka-admin/
├── ms-digitalfix-kafka-analytics/
├── digitalfix-ms-workorders/
└── frontend-digitalfix/
Para utilizar SSE, se debe seleccionar la rama feature/actualizacion-tiempo-real de Analytics y feature/dashboard-monitor-en-vivo del frontend. La infraestructura Kafka mantiene su configuración en main.
Inicio de servicios
Desde el directorio padre (DigitalFix/), ejecutar:

1. Iniciar Kafka, ZooKeeper y Kafka UI:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml up -d
2. Inicializar los tópicos:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
3. Construir e iniciar Kafka Admin y Analytics:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
4. Comprobar el estado:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps ps
Al estar todos los servicios iniciados, se esperan nueve contenedores en ejecución: tres ZooKeeper, tres brokers, Kafka UI, Kafka Admin y Kafka Analytics. kafka-init es un proceso temporal, por lo que no permanece activo.
Puertos: el mapeo predeterminado de Kafka Admin es 127.0.0.1:8090:8090. Si está reservado, puede modificarse el puerto del host (por ejemplo, 127.0.0.1:18090:8090) sin alterar el puerto interno del servicio.

Endpoints y administración
Servicio	Dirección	Uso
Kafka UI	http://localhost:8088	Visualización del clúster, tópicos y mensajes
Kafka Admin	http://localhost:8090/api/kafka/topics	Listado y administración de tópicos
Kafka Admin	http://localhost:8090/api/kafka/groups	Consulta de grupos de consumidores
Kafka Analytics	http://localhost:8091/api/analytics/resumen	Resumen de métricas
Kafka Analytics con SSE	http://localhost:8091/api/analytics/stream	Suscripción a eventos de actualización


Kafka Admin contempla operaciones REST para crear, consultar, modificar y eliminar tópicos de prueba, ampliar particiones y consultar grupos de consumidores, sus offsets y su lag.
Operación y diagnóstico
Consultar logs de Analytics:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps logs --tail=100 kafka-analytics
Detener los servicios sin eliminar volúmenes:
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps stop
Evitar down -v cuando se necesite conservar el contenido de los volúmenes persistentes de Kafka.
6. Despliegue del backend en AWS
El backend principal utiliza el archivo [`infra/apps/compose.yml`](infra/apps/compose.yml) y las variables de entorno correspondientes al servidor.

Desde el directorio padre que contiene digitalfix-infra/:
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env build
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env up -d
docker compose -f digitalfix-infra/infra/apps/compose.yml --env-file .env ps
El entorno AWS de BFF, Workorders y Catalog es independiente del Compose utilizado para el clúster Kafka. La configuración de la mensajería RabbitMQ y de otros servicios asociados se administra conforme a su propio despliegue.
7. Seguridad y configuración sensible
Las credenciales, tokens, archivos .env, certificados y Oracle Wallet no deben incorporarse al control de versiones.
- Administrar los secretos mediante variables de entorno o mecanismos seguros de aprovisionamiento.
- Mantener Oracle Wallet fuera de los repositorios y montarlo con los permisos mínimos necesarios.
- Evitar exponer directamente los puertos internos de los microservicios.
- Aplicar controles de autenticación y autorización antes de habilitar APIs de administración o SSE fuera de un entorno confiable.
- No incluir credenciales ni valores sensibles en documentación, comandos de ejemplo o registros públicos.
La autenticación del backend principal y las rutas de AWS no deben confundirse con los endpoints locales utilizados para Kafka.
8. Repositorios relacionados
Componente	Repositorio
Workorders	digitalfix-ms-workorders
BFF	digitalfix-ms-bff
Frontend	frontend-digitalfix
Kafka Admin	ms-digitalfix-kafka-admin
Kafka Analytics	ms-digitalfix-kafka-analytics
Rabbit Admin	ms-digitalfix-rabbit-admin
Notify	ms-digitalfix-notify


9. Alcance de la solución
DigitalFix separa las responsabilidades de persistencia, mensajería y visualización:
- Oracle Database: persistencia de las entidades de negocio.
- RabbitMQ: mensajería orientada a procesos operativos.
- Apache Kafka: distribución y conservación temporal de eventos.
- Kafka Analytics: procesamiento, clasificación y consulta de métricas en memoria.
- SSE + Angular: actualización de indicadores y visualizaciones mediante notificaciones desde el backend, en las ramas indicadas.
Esta separación permite extender la capacidad analítica del sistema sin modificar el propósito principal de los servicios existentes.
