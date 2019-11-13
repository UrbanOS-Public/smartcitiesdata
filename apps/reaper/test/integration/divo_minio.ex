defmodule Reaper.DivoMinio do
  @moduledoc """
  Sets up Minio as a local S3 alternative
  """

  def gen_stack(envar \\ []) do
    port = Keyword.get(envar, :port, 9000)

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
