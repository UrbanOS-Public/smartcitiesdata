# Runtime Configuration Guide

**Date:** 2025-12-01
**Purpose:** Document the runtime configuration system and required environment variables

## Overview

As of the OTP25 migration, the project uses `config/runtime.exs` for production configuration. This allows services to be configured at runtime through environment variables without requiring a rebuild.

## Required Environment Variables

### Kafka Configuration

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `KAFKA_BROKERS` | `localhost:9092` | Comma-separated list of Kafka broker addresses | `kafka1.prod:9092,kafka2.prod:9092,kafka3.prod:9092` |
| `EVENT_STREAM_TOPIC` | `event-stream` | Kafka topic for event streaming | `event-stream` |
| `DEAD_LETTER_TOPIC` | `streaming-dead-letters` | Kafka topic for dead letters | `streaming-dead-letters` |

### Redis Configuration

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `REDIS_HOST` | `localhost` | Redis server hostname | `redis.prod.internal` |
| `REDIS_PORT` | `6379` | Redis server port | `6379` |
| `REDIS_PASSWORD` | _(not set)_ | Redis password (optional) | `supersecretpassword` |

## Configuration Architecture

### Components Configured

#### 1. DeadLetter

All services use the `dead_letter` library for handling failed messages.

**Configuration:**
```elixir
config :dead_letter,
  driver: [
    module: DeadLetter.Carrier.Kafka,
    init_args: [
      endpoints: kafka_brokers,
      topic: dead_letter_topic
    ]
  ]
```

**Purpose:** Routes failed messages to a dead letter queue for later investigation.

#### 2. Brook Event Processing

Nine services use Brook for event-driven architecture:
- alchemist
- andi
- discovery_api
- discovery_streams
- forklift
- raptor
- reaper
- template
- valkyrie

**Configuration Pattern:**
```elixir
config :app_name, :brook,
  instance: :app_name,
  driver: [
    module: Brook.Driver.Kafka,
    init_arg: [
      endpoints: kafka_brokers,
      topic: event_stream_topic,
      group: "app-name-events",
      consumer_config: [
        begin_offset: :earliest,
        offset_reset_policy: :reset_to_earliest
      ]
    ]
  ],
  handlers: [AppName.Event.EventHandler],
  storage: [
    module: Brook.Storage.Redis,
    init_arg: [
      redix_args: [host: redis_host, port: redis_port],
      namespace: "app_name:view"
    ]
  ]
```

**Components:**
- **Driver:** Kafka-based event sourcing
- **Handlers:** Application-specific event handlers
- **Storage:** Redis-backed view storage with namespaced keys

## Kubernetes Deployment

### Environment Variables in K8s

Add these environment variables to your Kubernetes deployment manifests:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forklift
spec:
  template:
    spec:
      containers:
      - name: forklift
        image: smartcitiesdata/forklift:2.0.0
        env:
        - name: KAFKA_BROKERS
          value: "kafka-1.kafka-svc:9092,kafka-2.kafka-svc:9092,kafka-3.kafka-svc:9092"
        - name: EVENT_STREAM_TOPIC
          value: "event-stream"
        - name: DEAD_LETTER_TOPIC
          value: "streaming-dead-letters"
        - name: REDIS_HOST
          value: "redis-master.redis-svc"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: password
```

### Using ConfigMaps

For easier management across multiple services:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: smartcities-config
  namespace: mdot-ride-dev-ns
data:
  KAFKA_BROKERS: "kafka-1.kafka-svc:9092,kafka-2.kafka-svc:9092,kafka-3.kafka-svc:9092"
  EVENT_STREAM_TOPIC: "event-stream"
  DEAD_LETTER_TOPIC: "streaming-dead-letters"
  REDIS_HOST: "redis-master.redis-svc"
  REDIS_PORT: "6379"
```

Then reference in deployments:

```yaml
envFrom:
- configMapRef:
    name: smartcities-config
- secretRef:
    name: smartcities-secrets
```

## Local Development

### Development vs Production

**Development/Test environments** use `config/dev.exs`, `config/test.exs`, or `config/integration.exs`.

**Production environments** use `config/prod.exs` + `config/runtime.exs`.

### Testing Runtime Configuration Locally

1. **Set environment variables:**
   ```bash
   export KAFKA_BROKERS="localhost:9092"
   export EVENT_STREAM_TOPIC="event-stream"
   export DEAD_LETTER_TOPIC="streaming-dead-letters"
   export REDIS_HOST="localhost"
   export REDIS_PORT="6379"
   ```

2. **Build production release:**
   ```bash
   env MIX_ENV=prod mix release forklift
   ```

3. **Run the release:**
   ```bash
   _build/prod/rel/forklift/bin/forklift start
   ```

4. **Check logs for configuration output:**
   ```bash
   _build/prod/rel/forklift/bin/forklift logs
   ```

   You should see:
   ```
   =============================================================================
   Runtime Configuration Loaded (MIX_ENV=prod)
   =============================================================================
   Kafka Brokers: [localhost: 9092]
   Event Stream Topic: event-stream
   Dead Letter Topic: streaming-dead-letters
   Redis Host: localhost:6379
   ...
   ```

## Troubleshooting

### Issue: Service crashes with "KeyError: key :driver not found"

**Cause:** `config/runtime.exs` is not being loaded or environment variables are not set.

**Solution:**
1. Verify `config/runtime.exs` exists in the release
2. Check that `MIX_ENV=prod` (runtime.exs only loads in prod)
3. Verify environment variables are set in the K8s deployment

### Issue: Service crashes with "Keyword.fetch![nil, :instance]"

**Cause:** Brook configuration is nil or incomplete.

**Solution:**
1. Check that the app has a brook configuration in `config/runtime.exs`
2. Verify Kafka brokers are reachable
3. Check logs for connection errors

### Issue: Redis connection errors

**Cause:** Redis configuration is incorrect or Redis is not accessible.

**Solution:**
1. Verify `REDIS_HOST` and `REDIS_PORT` are correct
2. Test Redis connectivity: `redis-cli -h $REDIS_HOST -p $REDIS_PORT ping`
3. Check if password is required and `REDIS_PASSWORD` is set
4. Verify network policies allow pod-to-redis communication

### Issue: Kafka connection errors

**Cause:** Kafka brokers are not reachable or misconfigured.

**Solution:**
1. Verify `KAFKA_BROKERS` format is correct: `host1:port1,host2:port2`
2. Test Kafka connectivity from the pod
3. Check if topics exist: `EVENT_STREAM_TOPIC` and `DEAD_LETTER_TOPIC`
4. Verify network policies allow pod-to-kafka communication

## Configuration Validation

### Startup Logging

The runtime configuration logs all settings (without sensitive data) on startup:

```
=============================================================================
Runtime Configuration Loaded (MIX_ENV=prod)
=============================================================================
Kafka Brokers: [{"kafka-1.kafka-svc", 9092}, {"kafka-2.kafka-svc", 9092}]
Event Stream Topic: event-stream
Dead Letter Topic: streaming-dead-letters
Redis Host: redis-master.redis-svc:6379
Redis Password: ***SET***

Brook instances configured:
  - alchemist
  - andi
  - discovery_api
  - discovery_streams
  - forklift
  - raptor
  - reaper
  - template
  - valkyrie

DeadLetter driver: DeadLetter.Carrier.Kafka
=============================================================================
```

### Checking Configuration in Running Pod

```bash
# Get environment variables
kubectl exec -it <pod-name> -- env | grep -E "KAFKA|REDIS|TOPIC"

# Check if runtime.exs is present in the release
kubectl exec -it <pod-name> -- ls -la /opt/app/releases/*/runtime.exs

# View recent logs for configuration output
kubectl logs <pod-name> --tail=100 | grep -A 20 "Runtime Configuration"
```

## Migration Notes

### Before OTP25 Migration

Configuration was expected to come from:
- Compile-time configs in `config/prod.exs`
- Potentially from external sources (not documented)

### After OTP25 Migration

Configuration comes from:
- `config/runtime.exs` (evaluated at release startup)
- Environment variables (as documented above)
- Sensible defaults for local development

### Changes Required

1. **Kubernetes deployments** - Add environment variables for Kafka/Redis
2. **Helm charts** - Add values for configuration
3. **CI/CD pipelines** - Ensure environment variables are set for integration tests with `MIX_ENV=prod`
4. **Documentation** - Update ops documentation with new environment variables

## Best Practices

1. **Use ConfigMaps for non-sensitive data** (Kafka brokers, topics)
2. **Use Secrets for sensitive data** (Redis passwords, API keys)
3. **Test production releases locally** before deploying to K8s
4. **Monitor startup logs** to verify configuration is correct
5. **Use consistent naming** across environments (dev, staging, prod)
6. **Document environment-specific values** in your deployment documentation

## Related Files

- `config/runtime.exs` - Runtime configuration implementation
- `config/prod.exs` - Production compile-time configuration
- `config/integration.exs` - Integration test configuration (reference)
- `apps/*/config/test.exs` - Unit test configuration (reference)

## See Also

- [20251201-deployment-troubleshooting.md](./20251201-deployment-troubleshooting.md) - Troubleshooting K8s deployment issues
- [20251201-why-e2e-didnt-catch-config-issue.md](./20251201-why-e2e-didnt-catch-config-issue.md) - Understanding the configuration gap
