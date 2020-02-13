defmodule Valkyrie.DatasetProcessorTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  describe "start/1" do
    setup do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}
      allow(Valkyrie.TopicManager.setup_topics(any()), return: topics)
      allow(Valkyrie.TopicManager.delete_topics(any()), return: topics)
      allow(Valkyrie.DatasetSupervisor.ensure_stopped(any()), return: :do_not_care)
      allow(Valkyrie.DatasetSupervisor.ensure_started(any()), return: :fake_process)
      %{dataset: dataset, input_topic: topics.input_topic, output_topic: topics.output_topic}
    end

    test "should setup topics", setup_params do
      Valkyrie.DatasetProcessor.start(setup_params.dataset)

      assert_called(Valkyrie.TopicManager.setup_topics(setup_params.dataset))
    end

    test "should start a new DatasetSupervisor", setup_params do
      Valkyrie.DatasetProcessor.start(setup_params.dataset)

      start_options = capture(Valkyrie.DatasetSupervisor.ensure_started(any()), 1)

      assert setup_params.dataset == Keyword.get(start_options, :dataset)
      assert setup_params.input_topic == Keyword.get(start_options, :input_topic)
      assert setup_params.output_topic == Keyword.get(start_options, :output_topic)
    end

    test "should delete the dataset and the topics", setup_params do
      Valkyrie.DatasetProcessor.delete(setup_params.dataset.id)
      assert_called(Valkyrie.TopicManager.delete_topics(setup_params.dataset.id))
    end
  end
end
