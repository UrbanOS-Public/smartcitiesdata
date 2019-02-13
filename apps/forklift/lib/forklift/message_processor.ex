defmodule Forklift.MessageProcessor do
  alias Forklift.MessageAccumulator
  @data_topic Application.get_env(:forklift, :data_topic)
  @registry_topic Application.get_env(:forklift, :registry_topic)

  def handle_messages(messages) do
    Enum.map(messages, &process_message/1)
    |> Enum.all?(fn x -> x == :ok end)
    |> case do
      true -> :ok
      false -> raise RuntimeError, "Unexpected error in MessageProcessor"
    end
  end


  defp process_message(%{topic: @registry_topic, value: _value}) do
    :ok
  end

  defp process_message(%{topic: @data_topic, value: value} = _message) do
    with {:ok, dataset_id, payload} <- extract_id_and_payload(value),
         {:ok, pid} <- start_server(dataset_id) do
      MessageAccumulator.send_message(pid, payload)
    else
      {:error, reason} -> raise RuntimeError, reason
    end

    :ok
  end

  defp extract_id_and_payload(value) do
    with {:ok, data} <- Jason.decode(value) do
      %{"payload" => payload, "metadata" => %{"dataset_id" => dataset_id}} = data

      {:ok, dataset_id, payload}
    else
      {:error, error} -> {:error, error.data}
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
