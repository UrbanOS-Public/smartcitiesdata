defmodule Valkyrie.DatasetProcessorTest do
  use ExUnit.Case
  import Mock

  alias SmartCity.TestDataGenerator, as: TDG

  describe "start/1" do
    test "should setup topics" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}
      
      with_mocks([
        {Valkyrie.TopicManager, [], [setup_topics: fn _ -> topics end, delete_topics: fn _ -> topics end]},
        {Valkyrie.DatasetSupervisor, [], [ensure_stopped: fn _ -> :do_not_care end, ensure_started: fn _ -> :fake_process end]}
      ]) do
        Valkyrie.DatasetProcessor.start(dataset)

        assert_called Valkyrie.TopicManager.setup_topics(dataset)
      end
    end

    test "should start a new DatasetSupervisor" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}
      
      with_mocks([
        {Valkyrie.TopicManager, [], [setup_topics: fn _ -> topics end, delete_topics: fn _ -> topics end]},
        {Valkyrie.DatasetSupervisor, [], [ensure_stopped: fn _ -> :do_not_care end, ensure_started: fn args -> 
          # Store the args for verification
          send(self(), {:ensure_started_called, args})
          :fake_process 
        end]}
      ]) do
        Valkyrie.DatasetProcessor.start(dataset)

        assert_receive {:ensure_started_called, start_options}
        assert dataset == Keyword.get(start_options, :dataset)
        assert "input_topic" == Keyword.get(start_options, :input_topic)
        assert "output_topic" == Keyword.get(start_options, :output_topic)
      end
    end

    test "should delete the dataset and the topics" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}
      
      with_mocks([
        {Valkyrie.TopicManager, [], [setup_topics: fn _ -> topics end, delete_topics: fn _ -> topics end]},
        {Valkyrie.DatasetSupervisor, [], [ensure_stopped: fn _ -> :do_not_care end, ensure_started: fn _ -> :fake_process end]}
      ]) do
        Valkyrie.DatasetProcessor.delete(dataset.id)
        assert_called Valkyrie.TopicManager.delete_topics(dataset.id)
      end
    end
  end
end
