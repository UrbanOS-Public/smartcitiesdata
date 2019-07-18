defmodule Valkyrie.TopicManagerTest do
  use ExUnit.Case
  use Placebo

  alias Valkyrie.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)

  test "creates a topic with the provided input topic name" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true

    dataset = TDG.create_dataset(id: "ds1")

    topics = TopicManager.setup_topics(dataset)

    expected_input_topic = "#{@input_topic_prefix}-ds1"
    assert expected_input_topic == Map.get(topics, :input_topic)
    assert_called Elsa.create_topic(Application.get_env(:valkyrie, :elsa_brokers), expected_input_topic)
  end

  test "verifies input and output topics are available" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), seq: [false, false, true]
    dataset = TDG.create_dataset(id: "ds1")

    topics = TopicManager.setup_topics(dataset)

    expected_input_topic = "#{@input_topic_prefix}-ds1"
  end
end
