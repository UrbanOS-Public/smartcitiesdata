defmodule Flair.DivoPresto do
  @moduledoc """
  Defines a presto stack compatible with divo
  for building a docker-compose file.
  """
  @behaviour Divo.Stack

  @impl Divo.Stack
  def gen_stack(envar \\ []) do
    %{
      metastore: %{
        image: "199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/metastore-testo:latest",
        depends_on: ["postgres"],
        ports: ["9083:9083"],
        command:
          ~s(/bin/bash -c "/opt/hive-metastore/bin/schematool -dbType postgres -validate || /opt/hive-metastore/bin/schematool -dbType postgres -initSchema;
          /opt/hive-metastore/bin/start-metastore")
      },
      postgres: %{
        logging: %{driver: "none"},
        image: "199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/postgres-testo:latest",
        ports: ["5432:5432"]
      },
      minio: %{
        image: "199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/minio-testo:latest",
        ports: ["9000:9000"]
      },
      presto: %{
        depends_on: ["metastore", "minio"],
        image: "199837183662.dkr.ecr.us-east-2.amazonaws.com/scos/presto-testo:latest",
        ports: ["8080:8080"],
        healthcheck: %{
          test: [
            "CMD-SHELL",
            ~s(curl -s http://localhost:8080/v1/info | grep -q '"starting":false')
          ],
          interval: "10s",
          timeout: "30s",
          retries: 10
        }
      }
    }
  end
end
