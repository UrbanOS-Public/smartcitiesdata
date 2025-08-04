defmodule DiscoveryStreams.TopicHelperTest do
  use ExUnit.Case
  import Mox
  use Properties, otp_app: :discovery_streams

  alias DiscoveryStreams.TopicHelper

  setup :verify_on_exit!

  getter(:topic_prefix, generic: true, default: "validated-")

  setup do
    # Configure endpoints for testing
    Application.put_env(:discovery_streams, :endpoints, [{"localhost", 9092}])
    # Override Elsa for testing
    Application.put_env(:discovery_streams, :elsa, ElsaMock)
    :ok
  end

  describe "topic_name/1" do
    test "should return given dataset_id prefixed with the topic prefix" do
      dataset_id = Faker.UUID.v4()
      assert "#{topic_prefix()}#{dataset_id}" == TopicHelper.topic_name(dataset_id)
    end
  end

  describe "dataset_id/1" do
    test "should return the dataset_id from the topic name" do
      dataset_id = Faker.UUID.v4()
      topic_name = "#{topic_prefix()}#{dataset_id}"
      assert dataset_id == TopicHelper.dataset_id(topic_name)
    end
  end

  test "should delete input topic when the topic names are provided" do
    dataset_id = Faker.UUID.v4()
    expect(ElsaMock, :delete_topic, fn _, _ -> :ok end)
    TopicHelper.delete_input_topic(dataset_id, ElsaMock)
  end
end
