defmodule Andi.Kafka do
  @moduledoc false
  require Logger

  alias SCOS.RegistryMessage

  def send_to_kafka(%RegistryMessage{} = dataset) do
    with dataset_id <- Map.get(dataset, :id),
         {:ok, encoded} <- RegistryMessage.encode(dataset) do
      :andi
      |> Application.get_env(:topic)
      |> Kaffe.Producer.produce_sync(dataset_id, encoded)
    else
      _ -> {:error, "Unable to parse jason for object #{inspect(dataset)}"}
    end
  end

  def send_to_kafka(_) do
    {:error, "Send to kafka only suppports SCOS.RegistryMessage structs"}
  end
end
