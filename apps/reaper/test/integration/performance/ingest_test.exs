defmodule Reaper.PerformanceTest do
  use ExUnit.Case

  use Performance.BencheeCase,
    otp_app: :reaper,
    endpoints: Application.get_env(:reaper, :elsa_brokers),
    topic_prefixes: ["raw"],
    log_level: :warn

  import Reaper.Application
  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper

  @instance_name Reaper.instance_name()

  @tag timeout: :infinity
  test "run performance test" do
    # big_data_file_details = host_data_file(100_000, 500)
    small_data_file_details = host_data_file(1_000, 10)

    benchee_opts = [
      inputs: %{
        # "big_file" => big_data_file_details,
        "small_file" => small_data_file_details
      },
      before_each: fn {_bypass, url, count, width} ->
        csv_overrides = %{
          technical: %{
            sourceType: "ingest",
            sourceFormat: "csv",
            cadence: "once",
            sourceUrl: url,
            sourceQueryParams: %{}
          }
        }

        dataset =
          Performance.create_dataset(
            overrides: csv_overrides,
            num_fields: width
          )

        topics = create_kafka_topics(dataset)

        {dataset, count, topics}
      end,
      under_test: fn {dataset, expected_count, topics} ->
        Brook.Event.send(@instance_name, dataset_update(), :author, dataset)

        {output_topic} = topics

        eventually(
          fn ->
            current_count = get_message_count(output_topic)

            Logger.info(fn -> "Measured record counts #{current_count} v. #{expected_count}" end)

            assert current_count >= expected_count
          end,
          100,
          5000
        )

        dataset
      end,
      after_each: fn dataset ->
        Reaper.Event.Handlers.DatasetDelete.handle(dataset)

        delete_kafka_topics(dataset)
      end,
      after_scenario: fn {bypass, _url, _count, _width} ->
        Bypass.down(bypass)
      end,
      time: 120,
      memory_time: 2,
      warmup: 10
    ]

    benchee_run(benchee_opts)
  end

  defp write_data_file(count, width) do
    Temp.track!()

    {:ok, fd, path} = Temp.open()
    Logger.info("Writing CSV file at #{path} with #{inspect(count)} lines and #{inspect(width)} columns")

    1..count
    |> Stream.map(fn _ -> generate_record(width) end)
    |> Enum.each(fn record -> IO.puts(fd, record) end)

    File.close(fd)

    Logger.info("Done writing CSV file to #{path}")

    {path, count, width}
  end

  defp host_data_file(count, width) do
    {path, count, width} = write_data_file(count, width)

    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/data.txt", fn conn ->
      conn = Plug.Conn.send_chunked(conn, 200)

      path
      |> File.stream!()
      |> Enum.reduce_while(conn, &chunky_data/2)
    end)

    url = "http://localhost:#{bypass.port}/data.txt"
    Logger.info("Hosting CSV file #{path} at #{url}")

    {bypass, url, count, width}
  end

  defp chunky_data(chunk, conn) do
    case Plug.Conn.chunk(conn, chunk) do
      {:ok, conn} -> {:cont, conn}
      {:error, :closed} -> {:halt, conn}
    end
  end

  defp generate_record(width) do
    1..width
    |> Enum.map(fn _ -> Faker.Person.name() end)
    |> Enum.join(",")
  end
end
