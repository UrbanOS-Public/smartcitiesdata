defmodule Reaper.PerformanceTest do
  use ExUnit.Case
  use Divo
  require Logger
  @moduletag :performance

  alias SmartCity.TestDataGenerator, as: TDG

  @num_fields_in_schema 500
  @num_records 100_000
  @brokers Application.get_env(:reaper, :elsa_brokers)
  @endpoints Application.get_env(:reaper, :elsa_brokers) |> Enum.map(fn {k, v} -> {to_charlist(k), v} end)

  setup do
    Application.ensure_all_started(:reaper)
    Redix.command(:smart_city_registry, ~w|config set stop-writes-on-bgsave-error no|)
    Process.sleep(5_000)

    :ok
  end

  @tag timeout: :infinity
  test "performance test" do
    dataset_prefix = random_string(10)
    Agent.start_link(fn -> 0 end, name: __MODULE__)
    data_file = write_data_file()

    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/data.txt", fn conn ->
      conn = Plug.Conn.send_chunked(conn, 200)

      data_file
      |> File.stream!()
      |> Enum.reduce_while(conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> {:cont, conn}
          {:error, :closed} -> {:halt, conn}
        end
      end)
    end)

    Benchee.run(
      %{
        "ingest" => fn -> ingest(bypass, dataset_prefix) end
      },
      time: 120,
      memory_time: 2,
      warmup: 10
    )
  end

  defp ingest(bypass, dataset_prefix) do
    count = Agent.get_and_update(__MODULE__, fn s -> {s, s + 1} end)
    dataset_id = "#{dataset_prefix}#{count}"
    schema = Enum.map(1..@num_fields_in_schema, fn i -> %{name: "name-#{i}", type: "string"} end)
    url = "http://localhost:#{bypass.port}/data.txt"

    query_params = %{}

    Logger.info("Creating dataset")

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          sourceType: "ingest",
          sourceFormat: "csv",
          cadence: "once",
          schema: schema,
          sourceUrl: url,
          sourceQueryParams: query_params
        }
      )

    Logger.info("Creating kafka topic for #{dataset_id}")

    SmartCity.Dataset.write(dataset)
    Elsa.create_topic(@brokers, "raw-#{dataset_id}")

    Patiently.wait_for!(
      fn ->
        {:ok, num_messages} = :brod.resolve_offset(@endpoints, "raw-#{dataset_id}", 0)
        Logger.warn("Number of messages on raw-#{dataset_id}: #{num_messages}")
        num_messages == @num_records
      end,
      dwell: 500,
      max_tries: 10_000
    )
  end

  defp write_data_file() do
    Temp.track!()

    {:ok, path} =
      Temp.open([], fn file ->
        1..@num_records
        |> Stream.map(fn _ -> generate_record() end)
        |> Enum.each(fn record -> IO.puts(file, record) end)
      end)

    path
  end

  defp generate_record() do
    1..@num_fields_in_schema
    |> Enum.map(fn _ -> Faker.Name.name() end)
    |> Enum.join(",")
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end
end
