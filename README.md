DigitalFix - Infraestructura

Repositorio de infraestructura y despliegue de DigitalFix, una plataforma de gestión de servicios técnicos desarrollada con arquitectura de microservicios.


Contiene la configuración del backend en AWS y la infraestructura de mensajería con Apache Kafka mediante Docker Compose. Estos entornos se documentan por separado para facilitar su mantenimiento y despliegue.
Integrantes
- Sebastián Ahumada
- Benjamín Gutiérrez

Tecnologías utilizadas
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
- Apache Kafka
- ZooKeeper
- Kafka UI
- RabbitMQ

Arquitectura
El backend de DigitalFix utiliza una arquitectura de microservicios desplegada en AWS.

Flujo principal:
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

Componentes desplegados
DigitalFix BFF
Servicio encargado de centralizar las solicitudes provenientes del frontend.

Características:
- Spring Boot
- Java 21
- Puerto interno 8081
- Comunicación con Workorders
- Comunicación con Catalog
- Validación de JWT
- Autorización por roles

Nombre del contenedor:
digitalfix-bff
Workorders
Microservicio encargado de la gestión de órdenes de trabajo.

Características:
- Spring Boot
- Java 21
- Puerto interno 8080
- Persistencia en Oracle Database
- Creación y consulta de órdenes
- Actualización de estados
- Validación de transiciones

Nombre del contenedor:
digitalfix-workorders
Catalog
Microservicio encargado de la gestión del catálogo técnico.

Características:
- Spring Boot
- Java 21
- Puerto interno 8082
- Persistencia en Oracle Database
- Consulta de servicios
- Creación y actualización de servicios

Nombre del contenedor:
digitalfix-catalog
Seguridad
El backend no se expone directamente a Internet.

El acceso externo se realiza mediante:
Internet
→ AWS API Gateway
→ JWT Authorizer
→ VPC Link
→ Network Load Balancer
→ EC2
→ BFF
AWS API Gateway utiliza un JWT Authorizer configurado con Microsoft Entra ID.

Scope utilizado:
access_as_user
Comportamiento validado:
Sin token      → 401 Unauthorized
Token inválido → 401 Unauthorized
Token válido   → Acceso permitido según rol
El BFF realiza una segunda validación de seguridad y autorización por roles.

Roles utilizados:
Admin
Supervisor
Cliente
Control de acceso

Permisos implementados:
Recurso	Admin	Supervisor	Cliente
Workorders - consultar	Sí	Sí	Sí
Workorders - crear	Sí	Sí	Sí
Workorders - cambiar estado	Sí	Sí	No
Catalog	Sí	Sí	No


El frontend aplica restricciones de navegación, pero la autorización real también se valida en el backend.
API Gateway
AWS API Gateway funciona como punto de entrada al backend.

Flujo:
Frontend
→ API Gateway
→ JWT Authorizer
→ VPC Link
→ Network Load Balancer
→ BFF
Las rutas protegidas requieren un token JWT válido.

Las solicitudes OPTIONS utilizadas para CORS se permiten sin autenticación.
Network Load Balancer
Se utiliza un Network Load Balancer interno para conectar API Gateway con el BFF desplegado en EC2.

El NLB recibe las solicitudes desde el VPC Link y las dirige hacia el servicio BFF.
VPC Link
El VPC Link permite que API Gateway acceda de forma privada a los recursos internos de la VPC.

Esto evita exponer directamente los puertos internos de los microservicios.
AWS EC2
Los servicios backend se ejecutan dentro de una instancia AWS EC2 mediante Docker.

Servicios ejecutados:
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
Todos los servicios se encuentran conectados mediante una red Docker interna.
Docker Compose
El archivo principal de despliegue se encuentra en:
infra/apps/compose.yml
La configuración levanta los siguientes servicios:
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
Los contenedores utilizan la red:
digitalfix-network
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
Variables de entorno
Las credenciales y configuraciones sensibles no se almacenan directamente en GitHub.

Variables utilizadas:
WORKORDERS_DB_USERNAME
WORKORDERS_DB_PASSWORD
CATALOG_DB_USERNAME
CATALOG_DB_PASSWORD
AZURE_TENANT_ID
AZURE_CLIENT_ID
El archivo:
.env
permanece únicamente en el servidor.
Archivos excluidos
El archivo .gitignore evita subir información sensible.

Se excluyen:
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
Oracle Database
Los microservicios Workorders y Catalog utilizan Oracle Database para persistencia.

Cada dominio utiliza su propia configuración de conexión.

Las credenciales se entregan mediante variables de entorno.
Oracle Wallet
Oracle Wallet se utiliza para realizar la conexión segura con Oracle Cloud Database.

El wallet:
- No se almacena en GitHub.
- No se incluye dentro de las imágenes Docker.
- Se monta como volumen de solo lectura.
Ruta utilizada dentro de los contenedores:
/opt/oracle/wallet
Despliegue
Desde la instancia EC2:
cd ~/digitalfix
Construir las imágenes:
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  build
Levantar los servicios:
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  up -d
Verificación
Para comprobar el estado de los contenedores:
docker compose \
  -f digitalfix-infra/infra/apps/compose.yml \
  --env-file .env \
  ps
También puede utilizarse:
docker ps
Contenedores esperados:
digitalfix-bff
digitalfix-workorders
digitalfix-catalog
Logs
Para revisar el BFF:
docker logs --tail 25 digitalfix-bff
Para Workorders:
docker logs --tail 25 digitalfix-workorders
Para Catalog:
docker logs --tail 25 digitalfix-catalog
Pruebas realizadas
Se validaron las siguientes funcionalidades:
- BFF desplegado en AWS EC2.
- Workorders desplegado mediante Docker.
- Catalog desplegado mediante Docker.
- Conexión de Workorders con Oracle Database.
- Conexión de Catalog con Oracle Database.
- Comunicación BFF → Workorders.
- Comunicación BFF → Catalog.
- API Gateway funcionando como punto de entrada.
- JWT Authorizer integrado con Microsoft Entra ID.
- Solicitud sin token → 401.
- Token inválido → 401.
- Token válido → acceso permitido.
- Acceso de Admin a Catalog.
- Acceso de Cliente a Workorders.
- Acceso de Cliente a Catalog → 403.
- CORS configurado para el frontend.
- Acceso directo al BFF desde Internet bloqueado.
- Contenedores funcionando correctamente en EC2.
Flujo completo de una solicitud
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
Estado del proyecto
Actualmente se encuentran implementados y validados:
- Arquitectura de microservicios.
- API Gateway.
- JWT Authorizer.
- Integración con Microsoft Entra ID.
- VPC Link.
- Network Load Balancer.
- AWS EC2.
- Docker.
- Docker Compose.
- BFF.
- Workorders.
- Catalog.
- Oracle Database.
- Oracle Wallet.
- Variables de entorno.
- Restricción de acceso externo directo a los microservicios.
Matriz de funcionalidades
La matriz reúne el alcance de DigitalFix para la Evaluación Parcial 2, indicando el estado de cada funcionalidad, su componente responsable y la evidencia para verificarla.
ID	Funcionalidad	Estado	Componente responsable	Evidencia verificable
F01	Frontend desplegado en AWS con HTTPS	Implementada	Angular, Nginx y Caddy	Dockerfile del frontend, configuración Nginx y acceso al sitio durante la demostración.
F02	Autenticación con Microsoft Entra ID y utilización de JWT	Implementada	Angular MSAL, Entra ID y BFF	Configuración MSAL y validación JWT y roles del BFF. Pruebas de acceso autorizado y rechazo de solicitudes inválidas.
F03	Consumo del backend mediante API Gateway	Implementada	Frontend, API Gateway y BFF	Configuración del consumo de API Gateway. Verificación de rutas, authorizer e integraciones en AWS.
F04	Backend desplegado e integrado con Oracle Database	Implementada	BFF, Workorders y Catalog	Docker Compose del backend, configuración de persistencia y consulta de datos desde el frontend.
F05	Clúster RabbitMQ de dos nodos	Implementada	rabbitmq-1 y rabbitmq-2	Verificación en AWS mediante docker ps y docker exec rabbitmq-1 rabbitmqctl cluster_status.
F06	Tres colas principales y sus respectivas DLQ	Implementada	RabbitMQ y Notify	Declaración de colas y DLQ. Consulta de colas y prueba de mensaje inválido enviado a q.cmd.email.dlq.
F07	Exchanges direct y topic con sus bindings	Implementada	Configuración RabbitMQ de Workorders y Notify	RabbitMqConfig.java, con cmd.direct, cmd.topic, cmd.dead.dlx y sus claves de enrutamiento.
F08	Administración de colas, exchanges y bindings mediante API REST	Implementada	Rabbit Admin	RabbitAdminController.java y DTO de entrada. Pruebas de creación y eliminación mediante /api/rabbit.
F09	Flujo completo de eventos con confirmación y manejo de errores	Implementada	Workorders, RabbitMQ y Notify	Productor de eventos y consumidores por dominio. Cambio de estado de una orden, procesamiento con ACK y rechazo con NACK sin reencolar hacia DLQ.


Resultado del alcance
Las nueve funcionalidades de esta matriz se declaran implementadas:

Porcentaje de implementación declarado: 9 / 9 × 100 = 100%.

Durante la presentación se demuestra su funcionamiento. El porcentaje evaluado depende de las funcionalidades efectivamente demostradas.
Alcance del procesamiento de Notify
Notify valida los eventos de Email, Dispatch y Report y registra su procesamiento en logs. Esta implementación demuestra el flujo de mensajería, el ACK manual y el tratamiento de errores mediante DLQ.
Evidencias de infraestructura
El archivo infra/apps/compose.yml publicado en este repositorio corresponde al backend base: BFF, Workorders y Catalog.

La configuración Compose utilizada para el clúster RabbitMQ y los servicios adicionales desplegados en AWS debe incorporarse al repositorio para permitir reproducir el ambiente completo.
Infraestructura Apache Kafka
La infraestructura Kafka permite publicar y consumir eventos de órdenes de trabajo y generar métricas de procesamiento. Esta integración complementa los flujos existentes de RabbitMQ, sin reemplazarlos.
Arquitectura Kafka
Frontend Angular
       |
       v
Workorders + Oracle Database
       |
       | Publica eventos de órdenes
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
Resumen de métricas en memoria
       |
       +---------------------------+
       |                           |
       v                           v
API REST /resumen          Notificaciones SSE
                                   |
                                   v
                            Dashboard Angular
Alcance: la infraestructura Kafka definida en este repositorio se ejecuta con Docker Compose y no debe confundirse con el despliegue del backend base en AWS EC2.
Componentes de la infraestructura
Componente	Cantidad	Puerto publicado	Función
ZooKeeper	3	Solo red Docker	Coordinación del clúster.
Kafka Broker	3	19092, 19093, 19094	Almacenamiento y replicación de mensajes.
Kafka UI	1	8088	Inspección de tópicos, mensajes y consumer groups.
Kafka Admin	1	8090	Administración de tópicos y grupos mediante API REST.
Kafka Analytics	1	8091	Consumo de eventos, generación de métricas y consulta de resultados.


La configuración se encuentra en [`kafka/docker-compose.yml`](kafka/docker-compose.yml). El servicio kafka-init está disponible mediante el perfil tools y los microservicios Admin y Analytics utilizan el perfil apps.
Tópicos Kafka
Tópico	Descripción
digitalfix.ordenes.eventos	Eventos de creación y cambios de estado.
digitalfix.analitica.eventos	Métricas derivadas de los eventos de órdenes.
digitalfix.ordenes.eventos.DLT	Eventos de órdenes que no se pudieron procesar.
digitalfix.analitica.eventos.DLT	Eventos de métricas que no se pudieron procesar.


Los cuatro tópicos se inicializan con los siguientes parámetros:
Parámetro	Configuración
Particiones	3
Factor de replicación	3
Réplicas mínimas sincronizadas	2
Retención de mensajes	604800000 ms (7 días)
Política de limpieza	delete


Estos valores se definen en [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh). El script crea los tópicos si no existen; no reemplaza la configuración de tópicos ya creados.
Productores y consumidores
- Workorders: publica eventos JSON en digitalfix.ordenes.eventos utilizando el identificador de la orden como key.
- Kafka Analytics: consume los eventos de órdenes, los valida y clasifica; después publica sus métricas en digitalfix.analitica.eventos.
- Consumidor de métricas: procesa el segundo tópico y mantiene un resumen consultable mediante REST.
Los grupos de consumo configurados son:
Consumer group	Tópico	Responsabilidad
digitalfix-analytics-workorders	digitalfix.ordenes.eventos	Transformación de órdenes en métricas.
digitalfix-analytics-metrics	digitalfix.analitica.eventos	Registro de métricas.


El manejo de eventos erróneos está implementado en KafkaErrorsConfig.java mediante validaciones, reintentos y derivación a los tópicos DLT. Las métricas agregadas se mantienen en memoria y se reinician al reiniciar Analytics. No se persisten en Oracle; Oracle almacena los datos de las órdenes.
Estructura para el despliegue
Los archivos Compose de Kafka utilizan rutas relativas para acceder a los demás repositorios. Deben ubicarse como directorios hermanos:
DigitalFix/
├── digitalfix-infra/
├── ms-digitalfix-kafka-admin/
├── ms-digitalfix-kafka-analytics/
├── digitalfix-ms-workorders/
└── frontend-digitalfix/
Los comandos siguientes se ejecutan desde la carpeta padre DigitalFix/.
1. Iniciar el clúster y Kafka UI
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml up -d
2. Inicializar los tópicos
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile tools run --rm kafka-init
3. Construir e iniciar los microservicios Kafka
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
4. Verificar servicios y revisar registros
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps ps
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps logs --tail=50 kafka-admin kafka-analytics
5. Detener los servicios
docker compose --project-directory . -f ./digitalfix-infra/kafka/docker-compose.yml --profile apps stop
Este comando detiene los contenedores sin eliminar sus volúmenes. No es necesario utilizar down -v para detener el entorno, ya que esa opción elimina también los volúmenes de datos.
Interfaces y endpoints
Servicio	Dirección	Función
Kafka UI	http://localhost:8088	Visualizar brokers, tópicos y mensajes.
Kafka Admin	http://localhost:8090/api/kafka/topics	Listar tópicos.
Kafka Admin	http://localhost:8090/api/kafka/groups	Listar consumer groups.
Kafka Analytics	http://localhost:8091/api/analytics/resumen	Consultar estadísticas y eventos recientes.


Los puertos publicados pueden ajustarse según la disponibilidad del entorno. Si cambia un puerto externo, los puertos internos de los microservicios pueden mantenerse.
Actualización del dashboard mediante SSE
La versión de desarrollo de DigitalFix incorpora notificaciones Server-Sent Events (SSE). Cuando Analytics registra una métrica, notifica a los clientes conectados y Angular vuelve a consultar los datos actualizados.

Las modificaciones se mantienen en ramas independientes de la versión principal:
- Kafka Analytics — rama feature/actualizacion-tiempo-real
- Frontend — rama feature/dashboard-monitor-en-vivo
Kafka transporta eventos entre microservicios; SSE se utiliza para notificar al navegador. Los servicios de streaming deben contar con controles de acceso apropiados antes de exponerse en producción.
Repositorios relacionados
- Kafka Admin
- Kafka Analytics
- Workorders
- Frontend DigitalFix
