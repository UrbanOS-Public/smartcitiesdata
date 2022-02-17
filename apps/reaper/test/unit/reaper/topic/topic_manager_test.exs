defmodule Reaper.Topic.TopicManagerTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  alias Reaper.Topic.TopicManager

  getter(:elsa_brokers, generic: true)
  getter(:output_topic_prefix, generic: true)

  test "should delete input topic when the topic names are provided" do
    ingestion_id = Faker.UUID.v4()
    allow(Elsa.delete_topic(any(), any()), return: :ok)
    TopicManager.delete_topic(ingestion_id)
    assert_called(Elsa.delete_topic(elsa_brokers(), "#{output_topic_prefix()}-#{ingestion_id}"))
  end
end
