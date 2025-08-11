defmodule Reaper.Topic.TopicManagerTest do
  use ExUnit.Case, async: false
  use Properties, otp_app: :reaper

  alias Reaper.Topic.TopicManager

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  setup do
    # Ensure Elsa is not already mocked
    try do
      :meck.unload(Elsa)
    rescue
      ErlangError -> :ok
    end
    
    :meck.new(Elsa, [:non_strict])
    
    on_exit(fn -> 
      try do
        :meck.unload(Elsa)
      rescue
        ErlangError -> :ok
      end
    end)
    
    :ok
  end

  test "should delete input topic when the topic names are provided" do
    ingestion_id = Faker.UUID.v4()
    expected_topic = "#{output_topic_prefix()}-#{ingestion_id}"
    expected_brokers = elsa_brokers()
    :meck.expect(Elsa, :delete_topic, fn ^expected_brokers, ^expected_topic -> :ok end)
    
    TopicManager.delete_topic(ingestion_id)
    
    assert :meck.called(Elsa, :delete_topic, [expected_brokers, expected_topic])
  end
end
