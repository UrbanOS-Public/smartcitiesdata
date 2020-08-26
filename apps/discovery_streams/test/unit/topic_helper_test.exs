defmodule DiscoveryStreams.TopicHelperTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryStreams.TopicHelper
  @input_topic_prefix Application.get_env(:discovery_streams, :topic_prefix, "transformed-")

  describe "topic_name/1" do
    test "should return given dataset_id prefixed with the topic prefix" do
      dataset_id = Faker.UUID.v4()
      assert "transformed-#{dataset_id}" == TopicHelper.topic_name(dataset_id)
    end
  end

  describe "dataset_id/1" do
    test "should return the dataset_id from the topic name" do
      dataset_id = Faker.UUID.v4()
      topic_name = "transformed-#{dataset_id}"
      assert dataset_id == TopicHelper.dataset_id(topic_name)
    end
  end

  test "should delete input topic when the topic names are provided" do
    dataset_id = Faker.UUID.v4()
    allow(Elsa.delete_topic(any(), any()), return: :ok)
    TopicHelper.delete_input_topic(dataset_id)
    assert_called(Elsa.delete_topic(TopicHelper.get_endpoints(), "#{@input_topic_prefix}#{dataset_id}"))
  end
end
