defmodule Performance.Cve do
  @moduledoc """
  Utilities for working with CVE data in performance tests
  """
  alias SmartCity.TestDataGenerator, as: TDG
  require Logger

  @messages %{
    map: File.read!(File.cwd!() <> "/lib/performance/cve/map_message.json") |> Jason.decode!(),
    spat: File.read!(File.cwd!() <> "/lib/performance/cve/spat_message.json") |> Jason.decode!(),
    bsm: File.read!(File.cwd!() <> "/lib/performance/cve/bsm_message.json") |> Jason.decode!()
  }

  def generate_messages(count, type, opts \\ []) do
    generate_data_messages(count, type, opts)
    |> Enum.map(&wrap_in_kafka_key/1)
  end

  def generate_data_messages(count, type, opts \\ []) do
    keys = Keyword.get(opts, :keys, :atoms)
    temporary_dataset = create_dataset()

    messages =
      1..count
      |> Enum.map(fn _ -> create_data_message(temporary_dataset, type) end)
      |> Enum.map(fn message ->
        case keys do
          :string ->
            message
            |> Jason.encode!()
            |> Jason.decode!()

          _ -> message
        end
      end)

    Logger.info("Generated #{length(messages)} #{inspect(type)} messages")

    messages
  end

  def create_dataset() do
    schema = [
      %{type: "string", name: "timestamp"},
      %{type: "string", name: "messageType"},
      %{type: "json", name: "messageBody"},
      %{type: "string", name: "sourceDevice"}
    ]

    TDG.create_dataset(technical: %{schema: schema, sourceType: "stream"})
  end

  defp create_data_message(dataset, type) do
    payload = %{
      timestamp: DateTime.utc_now(),
      messageType: String.upcase(to_string(type)),
      messageBody: @messages[type],
      sourceDevice: "yidontknow"
    }

    TDG.create_data(dataset_id: dataset.id, payload: payload)
  end

  defp wrap_in_kafka_key(message) do
    {"", message}
  end
end
