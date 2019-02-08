# defmodule MessageRouter do
#   def handle_messages(messages) do

#     with {:ok, _pid} <- start_server(dataset_id) do
#       case GenServer.call(dataset_id, filtered_messages) do
#         :uploaded -> :ok
#         :batch_wait -> {:ok, :no_commit}
#       end
#     else
#       {:error, reason} -> raise RuntimeError, reason
#     end
#   end

#   defp start_server(dataset_id) do
#     case MessageCollector.start_link(dataset_id) do
#       {:ok, pid} -> {:ok, pid}
#       {:error, {:already_started, pid}} -> {:ok, pid}
#       _error -> {:error, "Error starting/locating GenServer"}
#     end
#   end
# end

defmodule Forklift.MessageProcessor do
  alias Forklift.DatasetServer

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
      DatasetServer.ingest_message(pid, message)
    else
      {:error, reason} -> raise RuntimeError, reason
    end

    :ok
  end

  defp start_server(dataset_id) do
    case DatasetServer.start_link(dataset_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      _error -> {:error, "Error starting/locating GenServer"}
    end
  end
end
