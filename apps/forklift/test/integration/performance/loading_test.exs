defmodule Forklift.Performance.LoadingTest do
  use ExUnit.Case

  use Performance.BencheeCase,
    otp_app: :forklift,
    endpoints: Application.get_env(:forklift, :elsa_brokers),
    topic_prefixes: ["transformed"],
    topics: ["streaming-persisted"],
    log_level: :warn

  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @instance_name Forklift.instance_name()

  @tag timeout: :infinity
  test "run performance test" do
    small_messages = Performance.generate_messages(10, 1_000)
    huge_messages = Performance.generate_messages(10, 1_000_000)

    {scenarios, _} =
      [{"huge", huge_messages}, {"small", small_messages}]
      |> Kafka.generate_consumer_scenarios()
      |> Map.split([
        "huge.mmb.hmw.mmib.lpc.lpb",
        "small.mmb.hmw.mmib.lpc.lpb"
      ])

    benchee_opts = [
      inputs: scenarios,
      before_scenario: fn input ->
        tune_consumer_parameters(input)

        input.messages
      end,
      before_each: fn messages ->
        width = Performance.get_message_width(messages)
        dataset = Performance.create_dataset(num_fields: width)
        count = length(messages)

        create_table(dataset)
        {input_topic, _output_topic} = topics = create_kafka_topics(dataset)

        load_messages(dataset, input_topic, messages)

        {dataset, count, topics}
      end,
      under_test: fn {dataset, expected_count, topics} ->
        Brook.Event.send(@instance_name, data_ingest_start(), :author, dataset)

        {_input_topic, output_topic} = topics

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
        Forklift.DataReaderHelper.terminate(dataset)

        delete_kafka_topics(dataset)
      end,
      time: 30,
      memory_time: 0.5,
      warmup: 0
    ]

    benchee_run(benchee_opts)
  end

  defp create_table(dataset) do
    num_fields = Enum.count(dataset.technical.schema)

    fields =
      1..num_fields
      |> Enum.map(fn i -> ~s|"name-#{i}" varchar| end)
      |> Enum.join(", ")

    prestige_opts()
    |> Prestige.new_session()
    |> Prestige.execute("create table #{dataset.technical.systemName} (#{fields})")
  end

  def prestige_opts() do
    Application.get_env(:prestige, :session_opts)
  end
end
