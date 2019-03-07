require Logger

defmodule Valkyrie.MessageHandler do
  @moduledoc false
  alias SCOS.DataMessage

  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, &handle_message/1)
    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
  end

  def handle_message(%{key: key, value: value}) do
    start_time = DataMessage.Timing.current_time()

    {:ok, new_value} = DataMessage.new(value)

    # ----
    # Do validations here
    # ----

    {:ok, new_value} =
      new_value
      |> DataMessage.add_timing(
        DataMessage.Timing.new(
          :valkyrie,
          :timing,
          start_time,
          DataMessage.Timing.current_time()
        )
      )
      |> DataMessage.encode()

    Kaffe.Producer.produce_sync(key, new_value)
  rescue
    MatchError -> Logger.debug("Got a bad message.")
  end
end
