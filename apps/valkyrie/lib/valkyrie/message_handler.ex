require Logger

defmodule Valkyrie.MessageHandler do
  alias SCOS.DataMessage

  def handle_messages(messages) do
    Logger.info("#{__MODULE__}: Received #{length(messages)} messages.")

    Enum.each(messages, fn %{key: key, value: value} ->
      start_time = DateTime.utc_now()

      new_value =
        value
        |> DataMessage.parse_message()
        |> DataMessage.put_operational(
          :valkyrie,
          :start_time,
          DateTime.to_iso8601(start_time)
        )

      # ----
      # Do validations here
      # ----

      duration = calc_duration(DateTime.utc_now(), start_time)

      new_value =
        new_value
        |> DataMessage.put_operational(:valkyrie, :duration, duration)
        |> DataMessage.encode_message()

      Kaffe.Producer.produce_sync(key, new_value)
    end)

    Logger.info("#{__MODULE__}: All messages handled without crashing.")

    :ok
  end

  defp calc_duration(end_time, start_time), do: DateTime.diff(end_time, start_time, :millisecond)
end
