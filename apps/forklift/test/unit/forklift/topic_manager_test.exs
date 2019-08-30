defmodule Forklift.TopicManagerTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_id "ds1"
  @endpoints Application.get_env(:forklift, :elsa_brokers)
  @input_topic_prefix Application.get_env(:forklift, :input_topic_prefix)

  test "returns the input topic name" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    dataset = TDG.create_dataset(id: @dataset_id)

    topics = TopicManager.setup_topics(dataset)

    assert "#{@input_topic_prefix}-#{@dataset_id}" == Map.get(topics, :input_topic)
  end

  test "creates a topic with the provided input topic name" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    dataset = TDG.create_dataset(id: @dataset_id)

    TopicManager.setup_topics(dataset)

    assert_called Elsa.create_topic(@endpoints, "#{@input_topic_prefix}-#{@dataset_id}")
  end

  test "verifies input topic is available" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{@input_topic_prefix}-#{@dataset_id}"), seq: [false, false, true]
    dataset = TDG.create_dataset(id: @dataset_id)

    TopicManager.setup_topics(dataset)

    assert_called Elsa.topic?(@endpoints, "#{@input_topic_prefix}-#{@dataset_id}"), times(3)
  end

  test "raises an error when it times out waiting for a topic" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{@input_topic_prefix}-#{@dataset_id}"), return: false
    dataset = TDG.create_dataset(id: @dataset_id)

    assert_raise RuntimeError, "Timed out waiting for #{@input_topic_prefix}-#{@dataset_id} to be available", fn ->
      TopicManager.setup_topics(dataset)
    end
  end
end
