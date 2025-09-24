defmodule Valkyrie.DatasetProcessorTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  describe "start/1" do
    test "should setup topics" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}

      # Setup mocks
      :meck.new(Valkyrie.TopicManager, [:passthrough])
      :meck.new(Valkyrie.DatasetSupervisor, [:passthrough])

      :meck.expect(Valkyrie.TopicManager, :setup_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.TopicManager, :delete_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_stopped, fn _ -> :do_not_care end)
      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_started, fn _ -> :fake_process end)

      Valkyrie.DatasetProcessor.start(dataset)

      assert :meck.num_calls(Valkyrie.TopicManager, :setup_topics, [dataset]) == 1

      # Cleanup
      :meck.unload(Valkyrie.TopicManager)
      :meck.unload(Valkyrie.DatasetSupervisor)
    end

    test "should start a new DatasetSupervisor" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}

      # Setup mocks
      :meck.new(Valkyrie.TopicManager, [:passthrough])
      :meck.new(Valkyrie.DatasetSupervisor, [:passthrough])

      :meck.expect(Valkyrie.TopicManager, :setup_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.TopicManager, :delete_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_stopped, fn _ -> :do_not_care end)

      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_started, fn args ->
        # Store the args for verification
        send(self(), {:ensure_started_called, args})
        :fake_process
      end)

      Valkyrie.DatasetProcessor.start(dataset)

      assert_receive {:ensure_started_called, start_options}
      assert dataset == Keyword.get(start_options, :dataset)
      assert "input_topic" == Keyword.get(start_options, :input_topic)
      assert "output_topic" == Keyword.get(start_options, :output_topic)

      # Cleanup
      :meck.unload(Valkyrie.TopicManager)
      :meck.unload(Valkyrie.DatasetSupervisor)
    end

    test "should delete the dataset and the topics" do
      dataset = TDG.create_dataset(%{})
      topics = %{input_topic: "input_topic", output_topic: "output_topic"}

      # Setup mocks
      :meck.new(Valkyrie.TopicManager, [:passthrough])
      :meck.new(Valkyrie.DatasetSupervisor, [:passthrough])

      :meck.expect(Valkyrie.TopicManager, :setup_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.TopicManager, :delete_topics, fn _ -> topics end)
      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_stopped, fn _ -> :do_not_care end)
      :meck.expect(Valkyrie.DatasetSupervisor, :ensure_started, fn _ -> :fake_process end)

      Valkyrie.DatasetProcessor.delete(dataset.id)

      assert :meck.num_calls(Valkyrie.TopicManager, :delete_topics, [dataset.id]) == 1

      # Cleanup
      :meck.unload(Valkyrie.TopicManager)
      :meck.unload(Valkyrie.DatasetSupervisor)
    end
  end
end
