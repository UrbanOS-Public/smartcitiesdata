require Logger

defmodule Valkyrie.MessageHandler do
  @moduledoc """
  Handle incoming data messages
  """
  alias SmartCity.Data
  alias Valkyrie.Validators

  @doc """
  Receives and validates a batch of data messages
  """
  @spec handle_messages(list(%{key: any(), value: any()})) :: :ok
  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, &handle_message/1)
    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
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
         {:ok, encoded_message} <- Jason.encode(updated_message) do
      Kaffe.Producer.produce_sync(key, encoded_message)
    else
      {:error, reason} ->
        Logger.warn("Error handling message: #{inspect(value)}: #{inspect(reason)}")
        Yeet.process_dead_letter("unknown", value, "Valkyrie", reason: inspect(reason))

      _ ->
        Logger.warn("Error handling message: #{inspect(value)}")
        Yeet.process_dead_letter("unknown", value, "Valkyrie")
    end
  end

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
