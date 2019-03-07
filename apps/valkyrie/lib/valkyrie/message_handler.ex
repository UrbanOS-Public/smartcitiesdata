require Logger

defmodule Valkyrie.MessageHandler do
  @moduledoc false
  alias SCOS.DataMessage
  alias SCOS.DataMessage.Timing

  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, fn %{key: key, value: value} ->
      start_time = Timing.current_time()

      new_value =
        value
        |> DataMessage.parse_message()

      # ----
      # Do validations here
      # ----

      new_value =
        new_value
        |> DataMessage.add_timing(Timing.new(:valkyrie, :timing, start_time, Timing.current_time()))
        |> IO.inspect(label: "message_handler.ex:27")
        |> DataMessage.encode_message()

      Kaffe.Producer.produce_sync(key, new_value)
    end)

    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
  end

  defp calc_duration(end_time, start_time), do: DateTime.diff(end_time, start_time, :millisecond)
end
