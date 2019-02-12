defmodule Andi.Kafka do
  @moduledoc false
  require Logger

  def send_to_kafka(%Dataset{} = dataset) do
    with dataset_id <- Map.get(dataset, :id),
         {:ok, encoded} <- Jason.encode(dataset) do
      Application.get_env(:andi, :topic)
      |> Kaffe.Producer.produce_sync(dataset_id, encoded)
    else
      _ -> {:error, "Unable to parse jason for object #{inspect(dataset)}"}
    end
  end

  def send_to_kafka(_) do
    {:error, "Send to kafka only suppports Dataset structs"}
  end
end
