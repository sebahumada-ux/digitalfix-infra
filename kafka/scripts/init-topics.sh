
#!/usr/bin/env bash
set -euo pipefail

# Brokers Kafka del clúster DigitalFix
BOOTSTRAP="kafka-1:9092,kafka-2:9092,kafka-3:9092"

echo "[INIT] Comprobando conexión con Kafka..."

for i in $(seq 1 60); do
    if kafka-topics \
        --bootstrap-server "$BOOTSTRAP" \
        --list >/dev/null 2>&1; then

        echo "[INIT] Kafka disponible."
        break
    fi

    if [ "$i" -eq 60 ]; then
        echo "[ERROR] Kafka no responde."
        exit 1
    fi

    sleep 5
done

# Función para crear tópicos
crear() {
    nombre="$1"
    retencion="$2"

    echo "[INIT] Creando tópico: $nombre"
    echo "[INIT] Particiones: 3 | Réplicas: 3"
    echo "[INIT] Retención: $retencion ms"

    for i in $(seq 1 30); do
        if kafka-topics \
            --bootstrap-server "$BOOTSTRAP" \
            --create \
            --if-not-exists \
            --topic "$nombre" \
            --partitions 3 \
            --replication-factor 3 \
            --config "retention.ms=$retencion" \
            --config "cleanup.policy=delete" \
            --config "min.insync.replicas=2"; then

            echo "[OK] Tópico disponible: $nombre"
            return 0
        fi

        if [ "$i" -eq 30 ]; then
            echo "[ERROR] No se pudo crear: $nombre"
            return 1
        fi

        sleep 5
    done
}

echo "===================================="
echo " DIGITALFIX - KAFKA EV3"
echo "===================================="

# Tópico principal de órdenes
crear "digitalfix.ordenes.eventos" 604800000

# Tópico principal de analítica
crear "digitalfix.analitica.eventos" 604800000

# Dead Letter Topics para mensajes fallidos
crear "digitalfix.ordenes.eventos.DLT" 604800000

crear "digitalfix.analitica.eventos.DLT" 604800000

echo "[INIT] Verificando tópicos principales..."

kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --describe \
    --topic "digitalfix.ordenes.eventos"

kafka-topics \
    --bootstrap-server "$BOOTSTRAP" \
    --describe \
    --topic "digitalfix.analitica.eventos"

echo "===================================="
echo "[OK] Configuración Kafka completada."
echo "[OK] 2 tópicos principales + 2 DLT."
echo "[OK] 3 particiones por tópico."
echo "[OK] Factor de replicación: 3."
echo "[OK] Retención: 7 días."
echo "[OK] min.insync.replicas: 2."
echo "===================================="

echo "Kafka UI: http://localhost:8088"
