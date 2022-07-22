use Mix.Config

config :pipeline,
  elsa_brokers: [{:localhost, 9092}],
  output_topic: "output-topic",
  producer_name: :"integration-producer",
  divo: "docker-compose.yml",
  divo_wait: [dwell: 1_000, max_tries: 120]

config :prestige, :session_opts,
  url: "http://localhost:8080",
  catalog: "hive",
  schema: "default",
  user: "foobar"

config :ex_aws,
  debug_requests: true,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin",
  region: "local"

config :ex_aws, :s3,
  scheme: "http://",
  region: "local",
  host: %{
    "local" => "localhost"
  },
  port: 9000

defmodule Pipeline.DivoPresto do
  @moduledoc """
  Defines a presto stack compatible with divo
  for building a docker-compose file.
  """

  def gen_stack(_envar) do
    %{
      metastore: %{
        image: "smartcitiesdata/metastore-testo:development",
        depends_on: ["postgres"],
        ports: ["9083:9083"],
        command:
          ~s(/bin/bash -c "/opt/hive-metastore/bin/schematool -dbType postgres -validate || /opt/hive-metastore/bin/schematool -dbType postgres -initSchema;
          /opt/hive-metastore/bin/start-metastore")
      },
      postgres: %{
        logging: %{driver: "none"},
        image: "smartcitiesdata/postgres-testo:development",
        ports: ["5432:5432"]
      },
      minio: %{
        image: "smartcitiesdata/minio-testo:development",
        ports: ["9000:9000"]
      },
      presto: %{
        depends_on: ["metastore", "minio"],
        image: "smartcitiesdata/presto-testo:development",
        ports: ["8080:8080"],
        healthcheck: %{
          test: [
            "CMD-SHELL",
            ~s(curl -s http://localhost:8080/v1/info | grep -q '"starting":false')
          ],
          interval: "10s",
          timeout: "60s",
          retries: 20
        }
      }
    }
  end
end
