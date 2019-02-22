defmodule Forklift.MessageProcessor do
  @moduledoc false
  require Logger
  alias Forklift.MessageAccumulator
  alias Forklift.DatasetRegistryServer

  def handle_messages(messages) do
    Enum.each(messages, &process_message/1)

    data_topic = data_topic()
    registry_topic = registry_topic()

    with ^data_topic <- assume_topic(messages) do
      :ok
    else
      ^registry_topic ->
        {:ok, :no_commit}

      topic ->
        Logger.warn("Unexpected topic #{topic} found in message stream. Ignoring")
        :ok
    end
  end

  defp assume_topic(messages) do
    topics =
      messages
      |> Enum.map(&Map.get(&1, :topic))
      |> Enum.dedup()

    case length(topics) do
      1 -> List.first(topics)
      _ -> raise RuntimeError, "Received mixed topics, this is probably a problem with Kaffe"
    end
  end

  defp process_message(%{topic: topic, value: value}) do
    case data_topic() == topic do
      true -> accumulate_value(value)
      _ -> DatasetRegistryServer.send_message(value)
    end
    :ok
  end

  defp accumulate_value(value) do
    with {:ok, dataset_id, payload} <- extract_id_and_payload(value),
         {:ok, pid} <- start_server(dataset_id) do
      MessageAccumulator.send_message(pid, payload)
    else
      {:error, reason} -> Logger.info("PROCESS MESSAGE FAILED: #{reason}")
    end

    :ok
  end

  defp extract_id_and_payload(value) do
    with {:ok, data} <- Jason.decode(value) do
      %{"payload" => payload, "metadata" => %{"dataset_id" => dataset_id}} = data

      {:ok, dataset_id, payload}
    else
      {:error, error} -> {:error, inspect(error)}
    end
  end

  defp start_server(dataset_id) do
    case MessageAccumulator.start_link(dataset_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      _error -> {:error, "Error starting/locating DataSet GenServer"}
    end
  end

  defp data_topic(), do: Application.get_env(:forklift, :data_topic)
  defp registry_topic(), do: Application.get_env(:forklift, :registry_topic)
end
