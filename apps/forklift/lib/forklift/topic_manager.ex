defmodule Forklift.TopicManager do
  @moduledoc """
  Create Topics in kafka
  """
  import Record, only: [defrecord: 2, extract: 2]

  @kafka_timeout Application.get_env(:forklift, :kafka_timeout, 5_000)

  defmodule Error do
    defexception [:code, :message]
  end

  defrecord :kpro_rsp, extract(:kpro_rsp, from_lib: "kafka_protocol/include/kpro.hrl")

  def create(topic, opts \\ []) do
    with_connection(endpoints(), fn connection ->
      topic_request = build_create_topic_request(connection, topic, opts)

      case send_request(connection, topic_request, @kafka_timeout) do
        :ok -> :ok
        {:error, :topic_already_exists, _message} -> :ok
        {:error, code, message} -> raise Error, code: code, message: message
        {:error, error} -> raise Error, code: :kafka_error, message: error
      end
    end)
  end

  defp build_create_topic_request(connection, topic, opts) do
    args = %{
      topic: topic,
      num_partitions: Keyword.get(opts, :partitions, 1),
      replication_factor: Keyword.get(opts, :replicas, 1),
      replica_assignment: [],
      config_entries: []
    }

    version = get_api_version(connection, :create_topics)
    :kpro_req_lib.create_topics(version, [args], %{timeout: @kafka_timeout})
  end

  defp endpoints() do
    Application.get_env(:kaffe, :consumer)[:endpoints]
  end

  defp with_connection(endpoints, fun) when is_function(fun) do
    endpoints
    |> :kpro.connect_any([])
    |> do_with_connection(fun)
  end

  defp get_api_version(connection, api) do
    {:ok, api_versions} = :kpro.get_api_versions(connection)
    {_, version} = Map.get(api_versions, api)
    version
  end

  defp do_with_connection({:ok, connection}, fun) do
    fun.(connection)
  after
    :kpro.close_connection(connection)
  end

  defp do_with_connection({:error, reason}, function) do
    raise Error,
      code: :with_connection_error,
      message: "#{format_reason(reason)}"
  end

  defp format_reason(reason) do
    cond do
      is_binary(reason) -> reason
      Exception.exception?(reason) -> Exception.format(:error, reason)
      true -> inspect(reason)
    end
  end

  defp send_request(connection, request, timeout) do
    case :kpro.request_sync(connection, request, timeout) do
      {:ok, response} -> check_response_for_errors(response)
      result -> result
    end
  end

  defp check_response_for_errors(response) do
    message = kpro_rsp(response, :msg)

    case Enum.find(message.topic_errors, fn error -> error.error_code != :no_error end) do
      nil -> :ok
      error -> {:error, error.error_code, error.error_message}
    end
  end
end
