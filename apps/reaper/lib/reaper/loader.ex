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
    value_part =
      %{dataset_id: dataset_id, payload: payload, _metadata: %{}, operational: %{}}
      |> DataMessage.new()
      |> DataMessage.encode_message()

    key_part = md5(value_part)

    {key_part, value_part}
  end

  defp md5(thing), do: :crypto.hash(:md5, thing) |> Base.encode16()
end
