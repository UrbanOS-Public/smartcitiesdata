defmodule Reaper.DivoMinio do
  @moduledoc """
  Sets up Minio as a local S3 alternative
  """

  def gen_stack(envar \\ []) do
    port = Keyword.get(envar, :port, 9000)
    bucket_name = Keyword.get(envar, :bucket, "hosted-dataset-files")
    access_key = Keyword.get(envar, :access_key, "access_key")
    secret_key = Keyword.get(envar, :secret_key, "secret_key")

    %{
      minio: %{
        image: "minio/minio",
        ports: ["#{port}:9000"],
        volumes: ["#{File.cwd!()}/test/support/minio_data:/data"],
        command: ["server", "/data"]
      }
    }
  end
end
