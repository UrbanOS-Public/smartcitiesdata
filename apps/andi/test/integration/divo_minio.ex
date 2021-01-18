defmodule Andi.DivoMinio do
  @moduledoc """
  Sets up Minio as a local S3 alternative
  """

  def gen_stack(envar \\ []) do
    port = Keyword.get(envar, :port, 9000)

    %{
      minio: %{
        image: "smartcitiesdata/minio-testo:development",
        ports: ["#{port}:9000"]
      }
    }
  end
end
