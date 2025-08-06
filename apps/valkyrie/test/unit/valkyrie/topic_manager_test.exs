defmodule Valkyrie.TopicManagerTest do
  use ExUnit.Case
  import Mock
  use Properties, otp_app: :valkyrie

  alias Valkyrie.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "ds1"

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "returns the input and output topic names" do
    with_mock(Elsa, create_topic: fn _, _ -> :doesnt_matter end, topic?: fn _, _ -> true end) do
      dataset = TDG.create_dataset(id: @dataset_id)

      topics = TopicManager.setup_topics(dataset)

      assert "#{input_topic_prefix()}-#{@dataset_id}" == Map.get(topics, :input_topic)
      assert "#{output_topic_prefix()}-#{@dataset_id}" == Map.get(topics, :output_topic)
    end
  end

  test "creates a topic with the provided input topic name" do
    with_mock(Elsa, create_topic: fn _, _ -> :doesnt_matter end, topic?: fn _, _ -> true end) do
      dataset = TDG.create_dataset(id: @dataset_id)

      TopicManager.setup_topics(dataset)

      assert_called Elsa.create_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@dataset_id}")
    end
  end

  test "verifies input and output topics are available" do
    input_topic = "#{input_topic_prefix()}-#{@dataset_id}"
    output_topic = "#{output_topic_prefix()}-#{@dataset_id}"
    
    :meck.new(Elsa)
    :meck.expect(Elsa, :create_topic, 2, :doesnt_matter)
    :meck.loop(Elsa, :topic?, 2, [false, false, true])

    dataset = TDG.create_dataset(id: @dataset_id)

    TopicManager.setup_topics(dataset)

    assert_called_exactly Elsa.topic?(elsa_brokers(), input_topic), 3
    assert_called_exactly Elsa.topic?(elsa_brokers(), output_topic), 3
    
    :meck.unload(Elsa)
  end

  test "raises an error when it times out waiting for a topic" do
    input_topic = "#{input_topic_prefix()}-#{@dataset_id}"
    output_topic = "#{output_topic_prefix()}-#{@dataset_id}"
    
    with_mock(Elsa, 
      create_topic: fn _, _ -> :doesnt_matter end,
      topic?: fn 
        _, ^input_topic -> true
        _, ^output_topic -> false
      end
    ) do
      dataset = TDG.create_dataset(id: @dataset_id)

      assert_raise RuntimeError, "Timed out waiting for #{output_topic_prefix()}-#{@dataset_id} to be available", fn ->
        TopicManager.setup_topics(dataset)
      end
    end
  end

  test "should delete input and output topic when the topic names are provided" do
    with_mock(Elsa, delete_topic: fn _, _ -> :doesnt_matter end) do
      TopicManager.delete_topics(@dataset_id)
      
      assert_called Elsa.delete_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@dataset_id}")
      assert_called Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id}")
    end
  end
end
