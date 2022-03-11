defmodule Alchemist.TopicManagerTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :alchemist

  alias Alchemist.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @ingestion_id "ingest1"
  @dataset_id "dataset1"

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "returns the input and output topic names" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDataset: @dataset_id})

    topics = TopicManager.setup_topics(ingestion)

    assert "#{input_topic_prefix()}-#{@ingestion_id}" == Map.get(topics, :input_topic)
    assert "#{output_topic_prefix()}-#{@dataset_id}" == Map.get(topics, :output_topic)
  end

  test "creates a topic with the provided input topic name" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), any()), return: true
    ingestion = TDG.create_ingestion(%{id: @ingestion_id})

    TopicManager.setup_topics(ingestion)

    assert_called Elsa.create_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}")
  end

  test "verifies input and output topics are available" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{input_topic_prefix()}-#{@ingestion_id}"), seq: [false, false, true]
    allow Elsa.topic?(any(), "#{output_topic_prefix()}-#{@dataset_id}"), seq: [false, false, true]
    ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDataset: @dataset_id})

    TopicManager.setup_topics(ingestion)

    assert_called Elsa.topic?(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"), times(3)
    assert_called Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id}"), times(3)
  end

  test "raises an error when it times out waiting for a topic" do
    allow Elsa.create_topic(any(), any()), return: :doesnt_matter
    allow Elsa.topic?(any(), "#{input_topic_prefix()}-#{@ingestion_id}"), return: true
    allow Elsa.topic?(any(), "#{output_topic_prefix()}-#{@dataset_id}"), return: false
    ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDataset: @dataset_id})

    assert_raise RuntimeError, "Timed out waiting for #{output_topic_prefix()}-#{@dataset_id} to be available", fn ->
      TopicManager.setup_topics(ingestion)
    end
  end

  test "should delete input and output topic when the topic names are provided" do
    allow(Elsa.delete_topic(any(), any()), return: :doesnt_matter)
    ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDataset: @dataset_id})
    TopicManager.delete_topics(ingestion)
    assert_called(Elsa.delete_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"))
    assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id}"))
  end
end
