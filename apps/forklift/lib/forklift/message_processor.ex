defmodule Forklift.MessageProcessor do
  alias Forklift.MessageAccumulator
  @data_topic Application.get_env(:forklift, :data_topic)
  @registry_topic Application.get_env(:forklift, :registry_topic)

  def handle_messages(messages) do
    Enum.each(messages, &process_message/1)

    case assume_topic(messages) do
      @data_topic ->
        :ok

      @registry_topic ->
        {:ok, :no_commit}

      e ->
        raise RuntimeError,
              "Unexpected topic #{e} does not match #{@data_topic} or #{@registry_topic}"
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

  defp process_message(%{topic: @registry_topic, value: value}) do
    DatasetRegistryServer.send_message(value)
    :ok
  end

  defp process_message(%{topic: @data_topic, value: value} = _message) do
    with {:ok, dataset_id, payload} <- extract_id_and_payload(value),
         {:ok, pid} <- start_server(dataset_id) do
      MessageAccumulator.send_message(pid, payload)
    else
      {:error, reason} -> reason |> IO.inspect(label: "PROCESS MESSAGE FAILED")
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
end
