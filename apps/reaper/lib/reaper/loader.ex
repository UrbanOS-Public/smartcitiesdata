defmodule Reaper.Loader do
  @moduledoc false
  alias Kaffe.Producer
  alias SCOS.DataMessage

  def load(payloads, dataset_id) do
    payloads
    |> Enum.map(&send_to_kafka(&1, dataset_id))
  end

  defp send_to_kafka(payload, dataset_id) do
    {key, message} = convert_to_message(payload, dataset_id)
    {Producer.produce_sync(key, message), payload}
  end

  defp convert_to_message(payload, dataset_id) do
    message_map = %{dataset_id: dataset_id, payload: payload, _metadata: %{}, operational: %{timing: []}}

    with {:ok, message} <- DataMessage.new(message_map),
         {:ok, value_part} <- DataMessage.encode(message) do
      key_part = md5(value_part)
      {key_part, value_part}
    end
  end

  defp md5(thing), do: :crypto.hash(:md5, thing) |> Base.encode16()
end
