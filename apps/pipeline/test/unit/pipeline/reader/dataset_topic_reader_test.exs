defmodule Pipeline.Reader.DatasetTopicReaderTest do
  use ExUnit.Case
  #use Placebo
  import Mox

  alias Pipeline.Reader.DatasetTopicReader
  alias Pipeline.Reader.TopicReader
  alias SmartCity.TestDataGenerator, as: TDG

  describe "init/1" do
    setup do
      [
        args: [
          dataset: TDG.create_dataset(%{}),
          instance: :foo,
          endpoints: Application.get_env(:pipeline, :elsa_brokers),
          input_topic_prefix: "heya",
          handler: MyTestHandler
        ]
      ]
    end

    test "inits TopicReader", %{args: args} do
      #expect TopicReader.init(any()), return: :ok
      assert DatasetTopicReader.init(args) == :ok
    end

    test "inits TopicReader with dataset specific connection", %{args: args} do
      expect TopicReader.init(any()),
        exec: fn init ->
          dataset = Keyword.get(args, :dataset)
          connection = Keyword.get(init, :connection) |> to_string()
          assert String.contains?(connection, dataset.id)
        end

      DatasetTopicReader.init(args)
    end

    test "inits TopicReader with dataset specific topic", %{args: args} do
      expect TopicReader.init(any()),
        exec: fn init ->
          dataset = Keyword.get(args, :dataset)
          topic = Keyword.get(init, :topic)
          assert topic == "heya-#{dataset.id}"
        end

      DatasetTopicReader.init(args)
    end
  end

  describe "terminate/1" do
    test "terminates TopicReader with dataset specific topic configuration" do
      dataset = TDG.create_dataset(%{})

      expect TopicReader.terminate(any()),
        exec: fn args ->
          topic = Keyword.get(args, :topic)
          assert topic == "delete-#{dataset.id}"
        end

      DatasetTopicReader.terminate(instance: :foo, dataset: dataset, input_topic_prefix: "delete")
    end
  end
end
