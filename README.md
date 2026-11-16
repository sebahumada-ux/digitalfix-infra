DigitalFix - Infraestructura
Repositorio de infraestructura de DigitalFix. Reúne el despliegue del backend en AWS EC2 y el entorno de Apache Kafka implementado.

Ambos entornos se documentan por separado: infra/apps/compose.yml corresponde al backend de AWS y kafka/docker-compose.yml al laboratorio Kafka local en Docker. La prueba Kafka local no equivale a un despliegue de Kafka en AWS.
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
- Apache Kafka y ZooKeeper (laboratorio EV3)
- Kafka UI
- Spring Kafka
- Server-Sent Events (SSE, mejora adicional en una rama de Analytics)
Infraestructura Apache Kafka — EV3
Objetivo
Para EV3 se agregó un sistema de mensajería por eventos que complementa la arquitectura existente sin sustituir Oracle ni RabbitMQ. Workorders guarda las órdenes en Oracle y puede publicar sus cambios en Kafka. Kafka Analytics consume eventos de órdenes, los clasifica y produce métricas en un segundo tópico. Kafka Admin ofrece una API REST para consultar y gestionar tópicos y grupos.

Este entorno se probó localmente con Docker en un computador de la universidad. La integración del dashboard mediante SSE es una mejora posterior ubicada en ramas de desarrollo, no en los main de frontend y Analytics.
Arquitectura Kafka
Angular / DigitalFix (4200)
           |
           v
Workorders (8080) --> Oracle Cloud Database
           |
           | Publicador Kafka (producer)
           v
digitalfix.ordenes.eventos
           |
           v
Kafka Analytics (consumer / clasificador)
           |
           | Produce métrica
           v
digitalfix.analitica.eventos
           |
           v
Kafka Analytics (consumer / resumen)
           |
           +--> GET /api/analytics/resumen (8091)
           |
           +--> SSE /api/analytics/stream (*) --> Dashboard Angular

Kafka Admin (8090) --> API REST de tópicos y grupos
Kafka UI (8088)    --> Inspección visual de brokers, tópicos y mensajes

(*) SSE disponible en la rama feature/actualizacion-tiempo-real de Analytics.
Componentes del laboratorio
Servicio	Cantidad	Función	Acceso desde el host
ZooKeeper	3	Coordinación del clúster usado en EV3	Red interna Docker
Brokers Kafka	3	Almacenar y replicar mensajes	localhost:19092, 19093, 19094
Kafka UI	1	Inspeccionar brokers, tópicos, particiones y mensajes	http://localhost:8088
Kafka Admin	1	Administración mediante API REST	http://localhost:8090
Kafka Analytics	1	Consumo de eventos y generación de métricas	http://localhost:8091


Los servicios kafka-admin y kafka-analytics utilizan el perfil de Compose apps; kafka-init utiliza el perfil tools y se ejecuta para inicializar los tópicos. El resto se inicia sin perfil.
Tópicos configurados
Tópico	Función
digitalfix.ordenes.eventos	Eventos emitidos al crear o cambiar una orden
digitalfix.analitica.eventos	Métricas derivadas de los eventos de órdenes
digitalfix.ordenes.eventos.DLT	Destino de órdenes que fallan durante el consumo
digitalfix.analitica.eventos.DLT	Destino de métricas que fallan durante el consumo


Los cuatro tópicos se crean con:
- 3 particiones por tópico.
- Factor de replicación 3.
- min.insync.replicas=2.
- retention.ms=604800000 (7 días).
- cleanup.policy=delete.
Estos parámetros se definen en [`kafka/scripts/init-topics.sh`](kafka/scripts/init-topics.sh). Se utiliza --if-not-exists para evitar errores al volver a ejecutar el script; esto no modifica la configuración de tópicos que ya existan.
Repositorios de los microservicios
- Kafka Admin — rama main.
- Kafka Analytics — implementación base en main.
- Workorders — productor real de órdenes en main.
- Frontend — frontend base en main.
Mejoras adicionales, no fusionadas a main:
- Analytics con SSE — rama feature/actualizacion-tiempo-real.
- Dashboard Live Monitor — rama feature/dashboard-monitor-en-vivo.
Despliegue del laboratorio en Windows (PowerShell)
La siguiente estructura fue utilizada en la prueba local:
DigitalFix_EV3/
├── digitalfix-infra/
├── ms-digitalfix-kafka-admin/
├── ms-digitalfix-kafka-analytics/
├── digitalfix-ms-workorders/
└── frontend-digitalfix/
Importante: ejecutar desde la carpeta padre DigitalFix_EV3, con los repositorios como carpetas hermanas. El Compose de Kafka utiliza estas rutas para construir Admin y Analytics.
1. Iniciar Docker Desktop y levantar Kafka, ZooKeeper y Kafka UI:
cd "C:\Users\va-alumno\Documents\DigitalFix_EV3"  # Ejemplo: reemplazar por la ubicación real

docker compose --project-directory . -f .\digitalfix-infra\kafka\docker-compose.yml up -d
2. Inicializar los cuatro tópicos:
docker compose --project-directory . -f .\digitalfix-infra\kafka\docker-compose.yml --profile tools run --rm kafka-init
3. Compilar las imágenes y ejecutar los microservicios de Kafka:
docker compose --project-directory . -f .\digitalfix-infra\kafka\docker-compose.yml --profile apps up -d --build kafka-admin kafka-analytics
4. Verificar el estado:
docker compose --project-directory . -f .\digitalfix-infra\kafka\docker-compose.yml --profile apps ps
El entorno completo de Kafka debe mostrar 9 contenedores activos: tres ZooKeeper, tres brokers, Kafka UI, Kafka Admin y Analytics. El contenedor efímero kafka-init finaliza después de crear los tópicos.

Nota de puertos: en uno de los computadores de la universidad, Windows impidió reservar 8090. Se cambió solo en la copia local el mapeo de Admin de 127.0.0.1:8090:8090 a 127.0.0.1:18090:8090. En el Compose publicado el puerto estándar continúa siendo 8090.
Verificación de funcionamiento
Herramienta	Dirección o navegación	Qué comprobar
Kafka UI	http://localhost:8088	3 brokers y los 4 tópicos
Kafka Admin	http://localhost:8090/api/kafka/topics	Listado de tópicos
Kafka Admin	http://localhost:8090/api/kafka/groups	Grupos consumidores
Kafka Analytics	http://localhost:8091/api/analytics/resumen	totalEventos, porCategoria y recientes
Kafka UI	Topics → digitalfix.ordenes.eventos → Messages	JSON enviado por Workorders, key, partición y offset
Kafka UI	Topics → digitalfix.analitica.eventos → Messages	Métrica procesada publicada por Analytics


Para probar el flujo real, Workorders debe ejecutarse por separado con Java 21, acceso a Oracle y su Wallet, y con KAFKA_ENABLED=true. El frontend local usa Angular y un proxy hacia Workorders; la rama Live Monitor también consume Analytics. No se incluyen credenciales en este repositorio.

Flujo comprobado en el laboratorio: crear una orden desde Angular, localizar su mensaje en digitalfix.ordenes.eventos, cambiar su estado a ASIGNADA y observar los eventos de creación y asignación en GET /api/analytics/resumen. La versión con SSE permitió observar la actualización del dashboard sin presionar F5.
Grupos de consumidores y errores
Analytics tiene dos consumidores en StreamListeners.java:
- Grupo digitalfix-analytics-workorders: consume el tópico de órdenes, valida y publica métricas.
- Grupo digitalfix-analytics-metrics: consume el tópico de analítica y actualiza el resumen.
La configuración utiliza concurrency=3, enable-auto-commit=false, ack-mode=record y auto-offset-reset=earliest cuando no hay offset válido.

KafkaErrorsConfig.java configura validaciones, registro de errores, reintentos para errores recuperables y envío a tópicos .DLT. Los mensajes considerados inválidos mediante IllegalArgumentException se tratan como no reintentables.

Persistencia: las órdenes se guardan en Oracle y los mensajes se conservan en Kafka durante la ventana de retención. El resumen (totalEventos, categorías y últimos 20 eventos) se mantiene en memoria en ResumenService.java, por lo que sus contadores se reinician al reiniciar Analytics. No hay una base de datos adicional de Analytics en esta implementación.
Detener el laboratorio sin borrar datos
docker compose --project-directory . -f .\digitalfix-infra\kafka\docker-compose.yml --profile apps stop
Este comando detiene los servicios y conserva los volúmenes de Docker. No utilizar down -v si se desea conservar los mensajes del laboratorio.
Seguridad y alcance
- No subir Oracle Wallet, contraseñas, .env, tokens ni certificados a GitHub.
- El laboratorio Kafka está pensado para ejecución local; no debe describirse como infraestructura Kafka desplegada en AWS.
- La autenticación JWT del sistema y las rutas de AWS corresponden al backend original y no deben confundirse con los endpoints locales de Kafka.
- La autenticación y autorización del stream SSE requieren endurecimiento antes de exponerlo en producción.
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
├── .gitattributes
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
