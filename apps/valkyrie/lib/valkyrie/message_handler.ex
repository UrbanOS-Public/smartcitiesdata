defmodule Valkyrie.MessageHandler do
  use Elsa.Consumer.MessageHandler

  @moduledoc """
  Handle incoming data messages
  """
  use Retry
  require Logger
  alias SmartCity.Data
  alias Valkyrie.Validators

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @initial_delay Application.get_env(:valkyrie, :produce_timeout)
  @retries Application.get_env(:valkyrie, :produce_retries)

  @doc """
  Receives and validates a batch of data messages
  """
  @spec handle_messages(list(%{key: any(), value: any()})) :: :ok
  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, &handle_message/1)
    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ack
  end

  @doc """
  Validates a single data message
  """
  @spec handle_message(%{key: any(), value: any()}) :: any() | {:error, String.t()}
  def handle_message(%{key: key, value: value}) do
    start_time = Data.Timing.current_time()

    with {:ok, new_value} <- Data.new(value),
         {:ok, validated_message} <- Validators.validate(new_value),
         {:ok, updated_message} <- set_operational_timing(start_time, validated_message),
         :ok <- produce_to_output_topic(key, updated_message) do
      :ok
    else
      {:error, reason} ->
        Logger.warn("Error handling message: #{inspect(value)}: #{inspect(reason)}")
        Yeet.process_dead_letter("unknown", value, "Valkyrie", reason: inspect(reason))

      _ ->
        Logger.warn("Error handling message: #{inspect(value)}")
        Yeet.process_dead_letter("unknown", value, "Valkyrie")
    end
  end

  defp produce_to_output_topic(key, datum) do
    topic = outgoing_topic(datum.dataset_id)
    message = Jason.encode!(datum)

    retry with: @initial_delay |> exponential_backoff() |> Stream.take(@retries), atoms: [false] do
      Valkyrie.TopicManager.is_topic_ready?(topic)
    after
      true ->
        Elsa.Producer.produce_sync(@endpoints, topic, 0, key, message)
    else
      error -> error
    end
  end

  defp outgoing_topic_prefix(), do: Application.get_env(:valkyrie, :output_topic_prefix)
  defp outgoing_topic(dataset_id), do: "#{outgoing_topic_prefix()}-#{dataset_id}"

  defp set_operational_timing(start_time, validated_message) do
    try do
      updated_message =
        validated_message
        |> Data.add_timing(
          Data.Timing.new(
            :valkyrie,
            :timing,
            start_time,
            Data.Timing.current_time()
          )
        )

      {:ok, updated_message}
    rescue
      _ -> {:error, "Failed to set operational timing."}
    end
  end
end
