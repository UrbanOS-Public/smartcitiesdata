defmodule Alchemist.IngestionProcessorTest do
  use ExUnit.Case

  import Mock

  alias SmartCity.TestDataGenerator, as: TDG

  @topics %{input_topic: "input_topic", output_topics: ["output_topic", "another_output_topic"]}

  describe "start/1" do
    setup_with_mocks([
      {Alchemist.TopicManager, [],
       [
         setup_topics: fn _ -> @topics end,
         delete_topics: fn _ -> @topics end
       ]},
      {Alchemist.IngestionSupervisor, [],
       [
         ensure_stopped: fn _ -> :do_not_care end,
         ensure_started: fn _ -> :fake_process end
       ]}
    ]) do
      ingestion = TDG.create_ingestion(%{})
      %{ingestion: ingestion, input_topic: @topics.input_topic, output_topics: @topics.output_topics}
    end

    test "should setup topics", setup_params do
      Alchemist.IngestionProcessor.start(setup_params.ingestion)

      assert_called(Alchemist.TopicManager.setup_topics(setup_params.ingestion))
      assert_called(Alchemist.IngestionSupervisor.ensure_started(:_))
    end

    # test "should start a new IngestionSupervisor", setup_params do
    #   Alchemist.IngestionProcessor.start(setup_params.ingestion)

    #   start_options = capture(Alchemist.IngestionSupervisor.ensure_started('_'), 1)

    #   assert setup_params.ingestion == Keyword.get(start_options, :ingestion)
    #   assert setup_params.input_topic == Keyword.get(start_options, :input_topic)
    #   assert setup_params.output_topics == Keyword.get(start_options, :output_topics)
    # end

    test "should delete the ingestion and the topics", setup_params do
      Alchemist.IngestionProcessor.delete(setup_params.ingestion)
      assert_called(Alchemist.TopicManager.delete_topics(setup_params.ingestion))
    end
  end
end
