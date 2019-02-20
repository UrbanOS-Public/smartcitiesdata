# Andi
A REST-API interface to putting Smart Columbus OS datasets into the registry

# Kafka Setup

To start up a local instance of kafka and zookeeper as dependencies for this project simply run 
`docker compose up -d`

# Running Andi

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

# Checking if messages were written to kafka

`docker exec -it andi_kafka_1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic dataset-registry --from-beginning`