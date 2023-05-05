defmodule Alchemist.IngestionProcessorTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  describe "start/1" do
    setup do
      ingestion = TDG.create_ingestion(%{})
      topics = %{input_topic: "input_topic", output_topics: ["output_topic", "another_output_topic"]}
      allow(Alchemist.TopicManager.setup_topics(any()), return: topics)
      allow(Alchemist.TopicManager.delete_topics(any()), return: topics)
      allow(Alchemist.IngestionSupervisor.ensure_stopped(any()), return: :do_not_care)
      allow(Alchemist.IngestionSupervisor.ensure_started(any()), return: :fake_process)
      %{ingestion: ingestion, input_topic: topics.input_topic, output_topics: topics.output_topics}
    end

    test "should setup topics", setup_params do
      Alchemist.IngestionProcessor.start(setup_params.ingestion)

      assert_called(Alchemist.TopicManager.setup_topics(setup_params.ingestion))
    end

    test "should start a new IngestionSupervisor", setup_params do
      Alchemist.IngestionProcessor.start(setup_params.ingestion)

      start_options = capture(Alchemist.IngestionSupervisor.ensure_started(any()), 1)

      assert setup_params.ingestion == Keyword.get(start_options, :ingestion)
      assert setup_params.input_topic == Keyword.get(start_options, :input_topic)
      assert setup_params.output_topics == Keyword.get(start_options, :output_topics)
    end

    test "should delete the ingestion and the topics", setup_params do
      Alchemist.IngestionProcessor.delete(setup_params.ingestion)
      assert_called(Alchemist.TopicManager.delete_topics(setup_params.ingestion))
    end
  end
end
