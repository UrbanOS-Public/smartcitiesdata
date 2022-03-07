defmodule Valkyrie.TopicManagerTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :valkyrie

  alias Valkyrie.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "ds1"

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "returns the input and output topic names" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    dataset = TDG.create_dataset(id: @dataset_id)

    topics = TopicManager.setup_topics(dataset)

    assert "#{input_topic_prefix()}-#{@dataset_id}" == Map.get(topics, :input_topic)
    assert "#{output_topic_prefix()}-#{@dataset_id}" == Map.get(topics, :output_topic)
  end

  test "creates a topic with the provided input topic name" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    dataset = TDG.create_dataset(id: @dataset_id)

    TopicManager.setup_topics(dataset)

    assert_called Elsa.create_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@dataset_id}")
  end

  test "verifies input and output topics are available" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{input_topic_prefix()}-#{@dataset_id}"), seq: [false, false, true]
    allow Elsa.topic?(any(), "#{output_topic_prefix()}-#{@dataset_id}"), seq: [false, false, true]
    dataset = TDG.create_dataset(id: @dataset_id)

    TopicManager.setup_topics(dataset)

    assert_called Elsa.topic?(elsa_brokers(), "#{input_topic_prefix()}-#{@dataset_id}"), times(3)
    assert_called Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id}"), times(3)
  end

  test "raises an error when it times out waiting for a topic" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{input_topic_prefix()}-#{@dataset_id}"), return: true
    allow Elsa.topic?(any(), "#{output_topic_prefix()}-#{@dataset_id}"), return: false
    dataset = TDG.create_dataset(id: @dataset_id)

    assert_raise RuntimeError, "Timed out waiting for #{output_topic_prefix()}-#{@dataset_id} to be available", fn ->
      TopicManager.setup_topics(dataset)
    end
  end

  test "should delete input and output topic when the topic names are provided" do
    allow(Elsa.delete_topic(any(), any()), return: :doesnt_matter)
    TopicManager.delete_topics(@dataset_id)
    assert_called(Elsa.delete_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@dataset_id}"))
    assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id}"))
  end
end
