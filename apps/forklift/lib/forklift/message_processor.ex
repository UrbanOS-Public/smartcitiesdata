defmodule Forklift.MessageProcessor do
  alias Forklift.DatasetStatem

  def handle_message(%{topic: topic} = message) do
    case topic do
      "registry-topic" -> process_registry_message(message)
      "data-topic" -> process_data_message(message)
    end
  end

  defp process_registry_message(message) do
    :ok
  end

  defp process_data_message(message) do
    dataset_id = "cota-whatever"

    with {:ok, pid} <- start_server(dataset_id) do
      DatasetStatem.send_message(pid, message)
    else
      {:error, reason} -> raise RuntimeError, reason
    end

    :ok
  end

  defp start_server(dataset_id) do
    case DatasetStatem.start_link(dataset_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      _error -> {:error, "Error starting/locating GenServer"}
    end
  end
end
