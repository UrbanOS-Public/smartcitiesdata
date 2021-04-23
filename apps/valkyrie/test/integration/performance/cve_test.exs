defmodule Valkyrie.Performance.CveTest do
  use ExUnit.Case

  use Performance.BencheeCase,
    otp_app: :valkyrie,
    endpoints: Application.get_env(:valkyrie, :elsa_brokers),
    topic_prefixes: ["raw", "transformed"],
    log_level: :warn

  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @instance_name Valkyrie.instance_name()

  @tag timeout: :infinity
  test "run performance test" do
    # map_messages = Cve.generate_messages(1_000, :map)
    spat_messages = Cve.generate_messages(10_000, :spat)
    bsm_messages = Cve.generate_messages(10_000, :bsm)

    {scenarios, _} =
      [{"spat", spat_messages}, {"bsm", bsm_messages}]
      |> Kafka.generate_consumer_scenarios()
      |> Map.split([
        # "map.lmb.lmw.lmib.lpc.lpb",
        # "map.mmb.mmw.lmib.lpc.hpb",
        "spat.lmb.lmw.lmib.lpc.lpb",
        "spat.mmb.mmw.lmib.lpc.hpb",
        "bsm.lmb.lmw.lmib.lpc.lpb",
        "bsm.mmb.mmw.lmib.lpc.hpb"
      ])

    benchee_opts = [
      inputs: scenarios,
      before_scenario: fn input ->
        tune_consumer_parameters(input)

        input.messages
      end,
      before_each: fn messages ->
        dataset = Cve.create_dataset()
        count = length(messages)

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
        Valkyrie.DatasetProcessor.stop(dataset.id)

        delete_kafka_topics(dataset)
      end,
      time: 30,
      memory_time: 0.5,
      warmup: 0
    ]

    benchee_run(benchee_opts)
  end
end
