#!/bin/sh
set -e

umask 077

BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-kafka:29092}"

# Required rather than defaulted: a baked-in topic list would silently diverge
# from the caller's and create the wrong topics.
: "${KAFKA_TOPICS:?set to a space- or comma-separated list of topic names}"
TOPICS="$KAFKA_TOPICS"

PARTITIONS="${KAFKA_TOPIC_PARTITIONS:-8}"
REPLICATION_FACTOR="${KAFKA_TOPIC_REPLICATION_FACTOR:-1}"
MIN_INSYNC_REPLICAS="${KAFKA_TOPIC_MIN_INSYNC_REPLICAS:-1}"
RETENTION_MS="${KAFKA_TOPIC_RETENTION_MS:-604800000}"
CLEANUP_POLICY="${KAFKA_TOPIC_CLEANUP_POLICY:-delete}"
MAX_MESSAGE_BYTES="${KAFKA_TOPIC_MAX_MESSAGE_BYTES:-4194304}"

BIN=/opt/kafka/bin

# Deployed brokers require mTLS, so the CLI needs a properties file. Unset
# locally, where the broker listens PLAINTEXT.
SECURITY_PROTOCOL="${KAFKA_SECURITY_PROTOCOL:-PLAINTEXT}"
CONFIG_FILE=/tmp/command.properties
CMD_CONFIG=""

if [ "$SECURITY_PROTOCOL" != "PLAINTEXT" ]; then
  : "${KAFKA_TLS_TRUSTSTORE_LOCATION:?required when KAFKA_SECURITY_PROTOCOL is not PLAINTEXT}"

  # Strimzi ships PKCS12 stores (ca.p12 / user.p12) in its cert secrets alongside
  # the PEM files, so point at those directly rather than converting.
  {
    echo "security.protocol=$SECURITY_PROTOCOL"
    echo "ssl.truststore.location=$KAFKA_TLS_TRUSTSTORE_LOCATION"
    echo "ssl.truststore.type=${KAFKA_TLS_TRUSTSTORE_TYPE:-PKCS12}"
    echo "ssl.truststore.password=${KAFKA_TLS_TRUSTSTORE_PASSWORD:-}"
    if [ -n "${KAFKA_TLS_KEYSTORE_LOCATION:-}" ]; then
      echo "ssl.keystore.location=$KAFKA_TLS_KEYSTORE_LOCATION"
      echo "ssl.keystore.type=${KAFKA_TLS_KEYSTORE_TYPE:-PKCS12}"
      echo "ssl.keystore.password=${KAFKA_TLS_KEYSTORE_PASSWORD:-}"
      echo "ssl.key.password=${KAFKA_TLS_KEY_PASSWORD:-${KAFKA_TLS_KEYSTORE_PASSWORD:-}}"
    fi
  } >"$CONFIG_FILE"

  CMD_CONFIG="--command-config $CONFIG_FILE"
fi

# shellcheck disable=SC2086 # CMD_CONFIG is an intentionally-split flag pair
topics_cmd() { "$BIN/kafka-topics.sh" --bootstrap-server "$BOOTSTRAP_SERVER" $CMD_CONFIG "$@"; }
# shellcheck disable=SC2086
configs_cmd() { "$BIN/kafka-configs.sh" --bootstrap-server "$BOOTSTRAP_SERVER" $CMD_CONFIG "$@"; }
# shellcheck disable=SC2086
ready_cmd() { "$BIN/kafka-broker-api-versions.sh" --bootstrap-server "$BOOTSTRAP_SERVER" $CMD_CONFIG; }

# accept comma- or space-separated lists
TOPICS=$(echo "$TOPICS" | tr ',' ' ')

# Bounded: over mTLS a bad cert or missing ACL is indistinguishable from "broker
# still starting", so an unbounded wait would hang forever instead of failing.
# Report the last error on timeout, otherwise the cause is invisible.
WAIT_TIMEOUT_SECONDS="${KAFKA_WAIT_TIMEOUT_SECONDS:-300}"
deadline=$(($(date +%s) + WAIT_TIMEOUT_SECONDS))

echo "waiting for kafka at $BOOTSTRAP_SERVER..."
while :; do
  if err=$(ready_cmd 2>&1); then
    break
  fi

  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "ERROR: kafka unreachable at $BOOTSTRAP_SERVER after ${WAIT_TIMEOUT_SECONDS}s" >&2
    echo "$err" | tail -5 >&2
    exit 1
  fi

  echo "kafka not ready yet, retrying in 2s..."
  sleep 2
done

partition_count() {
  topics_cmd --describe --topic "$1" 2>/dev/null \
    | sed -n 's/.*PartitionCount: *\([0-9]*\).*/\1/p' | head -1
}

create() {
  topic="$1"

  if ! topics_cmd --list 2>/dev/null | grep -Fqx "$topic"; then
    echo "creating topic $topic"
    topics_cmd \
      --create --if-not-exists --topic "$topic" \
      --partitions "$PARTITIONS" \
      --replication-factor "$REPLICATION_FACTOR" \
      --config "cleanup.policy=$CLEANUP_POLICY" \
      --config "retention.ms=$RETENTION_MS" \
      --config "max.message.bytes=$MAX_MESSAGE_BYTES" \
      --config "min.insync.replicas=$MIN_INSYNC_REPLICAS"
    return
  fi

  # Existing topic: converge config so changing retention here takes effect on a
  # re-run instead of silently applying only to new topics.
  echo "topic $topic exists, reconciling config"
  configs_cmd \
    --entity-type topics --entity-name "$topic" --alter \
    --add-config "cleanup.policy=$CLEANUP_POLICY,retention.ms=$RETENTION_MS,max.message.bytes=$MAX_MESSAGE_BYTES,min.insync.replicas=$MIN_INSYNC_REPLICAS" \
    >/dev/null

  current=$(partition_count "$topic")
  if [ -n "$current" ] && [ "$current" -lt "$PARTITIONS" ]; then
    echo "increasing $topic partitions $current -> $PARTITIONS"
    topics_cmd --alter --topic "$topic" --partitions "$PARTITIONS"
  elif [ -n "$current" ] && [ "$current" -gt "$PARTITIONS" ]; then
    # Kafka cannot reduce partitions; recreating would drop buffered records.
    echo "WARNING: $topic has $current partitions, more than the requested $PARTITIONS; leaving as-is"
  fi
}

for topic in $TOPICS; do
  create "$topic"
done

echo "topics ready:"
topics_cmd --list | grep -v '^__' || true
