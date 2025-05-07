defmodule Alchemist.TopicManagerTest do
  use ExUnit.Case
  use Properties, otp_app: :alchemist

  import Mock

  alias Alchemist.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  @ingestion_id "ingest1"
  @dataset_id1 "dataset1"
  @dataset_id2 "dataset2"

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "returns the input and output topic names" do
    with_mock(Elsa, create_topic: fn _, _ -> :doesnt_matter end, topic?: fn _, _ -> true end) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1, @dataset_id2]})

      topics = TopicManager.setup_topics(ingestion)

      assert "#{input_topic_prefix()}-#{@ingestion_id}" == Map.get(topics, :input_topic)

      assert [
               "#{output_topic_prefix()}-#{@dataset_id1}",
               "#{output_topic_prefix()}-#{@dataset_id2}"
             ] == Map.get(topics, :output_topics)
    end
  end

  test "creates a topic with the provided input topic name" do
    with_mock(Elsa, create_topic: fn _, _ -> :doesnt_matter end, topic?: fn _, _ -> true end) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id})

      TopicManager.setup_topics(ingestion)

      assert_called Elsa.create_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}")
    end
  end

  test "verifies input and output topics are available" do
    :meck.new(Elsa)
    :meck.expect(Elsa, :create_topic, 2, :doesnt_matter)
    :meck.loop(Elsa, :topic?, 2, [false, false, true])

    ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1]})

    TopicManager.setup_topics(ingestion)

    assert_called_exactly(Elsa.topic?(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"), 3)
    assert_called_exactly(Elsa.topic?(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id1}"), 3)

    :meck.unload()
    # end
  end

  test "raises an error when it times out waiting for a topic" do
    with_mock(Elsa,
      create_topic: fn _, _ -> :doesnt_matter end,
      topic?: fn _, _ingestion_input -> true end,
      topic?: fn _, _dataset_output -> false end
    ) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1]})

      assert_raise RuntimeError,
                   "Timed out waiting for #{"#{input_topic_prefix()}-#{@ingestion_id}"} to be available",
                   fn ->
                     TopicManager.setup_topics(ingestion)
                   end
    end
  end

  test "should delete input and output topic when the topic names are provided" do
    with_mock(Elsa, delete_topic: fn _, _ -> :doesnt_matter end) do
      ingestion = TDG.create_ingestion(%{id: @ingestion_id, targetDatasets: [@dataset_id1, @dataset_id2]})
      TopicManager.delete_topics(ingestion)
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{input_topic_prefix()}-#{@ingestion_id}"))
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id1}"))
      assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{@dataset_id2}"))
    end
  end
end
