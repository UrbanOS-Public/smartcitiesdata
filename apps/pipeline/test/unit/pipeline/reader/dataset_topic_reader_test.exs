defmodule Pipeline.Reader.DatasetTopicReaderTest do
  use ExUnit.Case
  use Pipeline.TestHelper

  alias Pipeline.Reader.DatasetTopicReader
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  describe "init/1" do
    test "inits TopicReader" do
      dataset = TDG.create_dataset(%{id: "test-dataset"})

      expect(TopicReaderMock, :init, fn [
        instance: :dataset_topic_reader_test,
        connection: :"dataset_topic_reader_test-test-topic-test-dataset-test-dataset-consumer",
        endpoints: [localhost: 9092],
        topic: "test-topic-test-dataset",
        handler: TestHandler,
        handler_init_args: [],
        topic_subscriber_config: [],
        retry_count: 10,
        retry_delay: 100
      ] -> :ok end)

      assert :ok ==
               DatasetTopicReader.init(
                 instance: :dataset_topic_reader_test,
                 dataset: dataset,
                 endpoints: [localhost: 9092],
                 input_topic_prefix: "test-topic",
                 handler: TestHandler
               )
    end
  end

  describe "terminate/1" do
    test "terminates TopicReader" do
      dataset = TDG.create_dataset(%{id: "test-dataset"})

      expect(TopicReaderMock, :terminate, fn [
        instance: :dataset_topic_reader_test,
        topic: "test-topic-test-dataset"
      ] -> :ok end)

      assert :ok ==
               DatasetTopicReader.terminate(
                 instance: :dataset_topic_reader_test,
                 dataset: dataset,
                 input_topic_prefix: "test-topic"
               )
    end
  end
end
