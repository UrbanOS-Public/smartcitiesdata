defmodule DiscoveryStreams.TopicHelperTest do
  use ExUnit.Case

  describe "topic_name/1" do
    test "should return given dataset_id prefixed with the topic prefix" do
      dataset_id = Faker.UUID.v4()
      assert "transformed-#{dataset_id}" == DiscoveryStreams.TopicHelper.topic_name(dataset_id)
    end
  end

  describe "dataset_id/1" do
    test "should return the dataset_id from the topic name" do
      dataset_id = Faker.UUID.v4()
      topic_name = "transformed-#{dataset_id}"
      assert dataset_id == DiscoveryStreams.TopicHelper.dataset_id(topic_name)
    end
  end
end
