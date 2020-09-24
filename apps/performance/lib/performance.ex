defmodule Performance do
  @moduledoc """
  Common performance test utilities
  """
  alias SmartCity.TestDataGenerator, as: TDG
  require Logger

  def generate_messages(width, count) do
    generate_data_messages(width, count)
    |> Enum.map(&wrap_in_kafka_key/1)
  end

  def generate_data_messages(width, count) do
    temporary_dataset = create_dataset(num_fields: width)

    messages =
      1..count
      |> Enum.map(fn _ -> create_data_message(temporary_dataset) end)

    Logger.info("Generated #{length(messages)} flat messages of width #{inspect(width)}")

    messages
  end

  def get_message_width(messages) do
    messages
    |> List.first()
    |> elem(1)
    |> Map.get(:payload)
    |> Map.keys()
    |> length()
  end

  def create_dataset(opts) do
    overrides = Keyword.get(opts, :overrides, %{})
    num_fields = Keyword.get(opts, :num_fields)
    schema = Enum.map(1..num_fields, fn i -> %{name: "name-#{i}", type: "string"} end)

    overrides = put_in(overrides, [:technical, :schema], schema)
    dataset = TDG.create_dataset(overrides)
    dataset
  end

  defp create_data_message(sample_dataset) do
    schema = sample_dataset.technical.schema

    payload =
      Enum.reduce(schema, %{}, fn field, acc ->
        Map.put(acc, field.name, "some value")
      end)

    TDG.create_data(dataset_id: sample_dataset.id, payload: payload)
  end

  defp wrap_in_kafka_key(message) do
    {"", message}
  end
end
