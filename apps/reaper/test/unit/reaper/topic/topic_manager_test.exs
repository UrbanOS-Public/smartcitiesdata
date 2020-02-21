defmodule Reaper.Topic.TopicManagerTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.Topic.TopicManager

  @endpoints Application.get_env(:reaper, :elsa_brokers)
  @output_topic_prefix Application.get_env(:reaper, :output_topic_prefix)

  test "should delete input topic when the topic names are provided" do
    dataset_id = Faker.UUID.v4()
    allow(Elsa.delete_topic(any(), any()), return: :ok)
    TopicManager.delete_topic(dataset_id)
    assert_called(Elsa.delete_topic(@endpoints, "#{@output_topic_prefix}-#{dataset_id}"))
  end
end
