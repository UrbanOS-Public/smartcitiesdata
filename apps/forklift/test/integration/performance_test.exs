defmodule Forklift.PerformanceTest do
  use ExUnit.Case
  use Divo
  require Logger

  alias SmartCity.TestDataGenerator, as: TDG

  @moduletag :performance

  @num_messages_per_iteration 1000
  @num_fields 10
  @number_of_pregenerated_messages 200_000

  @outgoing_topic "streaming-persisted"
  @endpoints Application.get_env(:kaffe, :producer)[:endpoints]

  setup_all do
    Logger.configure(level: :warn)
    Agent.start(fn -> 0 end, name: :counter)

    [outgoing_partitions: get_number_of_partitions(@outgoing_topic)]
  end

  @tag timeout: :infinity
  test "run performance test", context do
    dataset = create_dataset(id: "performance_ds", num_fields: @num_fields)
    create_table(dataset.technical.systemName)
    Forklift.TopicManager.create("integration-performance_ds")

    num_producers = div(@number_of_pregenerated_messages, 10_000)

    Logger.warn("Preloading messages into kafka")

    1..num_producers
    |> Enum.map(fn _ ->
      Task.async(fn ->
        Stream.repeatedly(fn -> create_data_message(dataset) end)
        |> Stream.take(10_000)
        |> Stream.chunk_every(50)
        |> Enum.each(fn messages -> Kaffe.Producer.produce_sync("integration-performance_ds", messages) end)
      end)
    end)
    |> Enum.each(&Task.await(&1, :infinity))

    Logger.warn("Done preloading messages")

    Forklift.Datasets.DatasetHandler.handle_dataset(dataset)

    Benchee.run(
      %{
        "kafka" => fn -> performance_test(context) end
      },
      time: 120,
      memory_time: 2,
      warmup: 10
    )
  end

  def performance_test(%{outgoing_partitions: outgoing_partitions}) do
    Logger.warn("Iteration - #{Agent.get_and_update(:counter, fn s -> {s, s + 1} end)}")
    starting_total = get_total_messages(@outgoing_topic, outgoing_partitions)

    Patiently.wait_for!(
      fn ->
        current_total = get_total_messages(@outgoing_topic, outgoing_partitions)
        Logger.warn("Starting total: #{starting_total}")
        Logger.warn("Current total: #{current_total}")
        current_total - starting_total >= @num_messages_per_iteration
      end,
      dwell: 2000,
      max_tries: 5000
    )
  end

  defp create_table(system_name) do
    fields =
      1..@num_fields
      |> Enum.map(fn i -> ~s|"name-#{i}" varchar| end)
      |> Enum.join(", ")

    "create table #{system_name} (#{fields})"
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  defp get_total_messages(topic, num_partitions) do
    0..(num_partitions - 1)
    |> Enum.map(fn partition -> :brod.resolve_offset(@endpoints, topic, partition) end)
    |> Enum.map(fn {:ok, value} -> value end)
    |> Enum.sum()
  end

  defp create_dataset(opts) do
    id = Keyword.get(opts, :id)
    num_fields = Keyword.get(opts, :num_fields)
    schema = Enum.map(1..num_fields, fn i -> %{name: "name-#{i}", type: "string"} end)

    dataset = TDG.create_dataset(id: id, technical: %{schema: schema, systemName: "performance_dataset"})
    dataset
  end

  defp create_data_message(dataset) do
    schema = dataset.technical.schema

    payload =
      Enum.reduce(schema, %{}, fn field, acc ->
        Map.put(acc, field.name, "some value")
      end)

    data = TDG.create_data(dataset_id: dataset.id, payload: payload)
    {to_string(:rand.uniform()), Jason.encode!(data)}
  end

  defp get_number_of_partitions(topic) do
    {:ok, metadata} = :brod.get_metadata(@endpoints, [topic])

    metadata
    |> Map.get(:topic_metadata)
    |> hd()
    |> Map.get(:partition_metadata)
    |> Enum.count()
  end
end
