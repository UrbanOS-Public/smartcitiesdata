defmodule Forklift.TopicManagerTest do
  use ExUnit.Case
  use Placebo

  describe "create_and_subscribe/1" do
    setup do
      allow :kpro_req_lib.create_topics(any(), any(), any()), return: :does_not_matter
      allow :kpro.get_api_versions(any()), return: {:ok, %{create_topics: {0, 1}}}
      allow :kpro.close_connection(any()), return: :does_not_matter
      :ok
    end

    test "raises an exception if the topic is neither created nor already exists" do
      kpro_resp =
        {:kpro_rsp, :does_not_matter, :create_topics, 2,
         %{
           throttle_time_ms: 0,
           topic_errors: [
             %{
               error_code: :some_other_error,
               error_message: "Something else went wrong",
               topic: "transformed-bob1"
             }
           ]
         }}

      allow :kpro.connect_controller(any(), any()), return: {:ok, :does_not_matter}
      allow :kpro.request_sync(any(), any(), any()), return: {:ok, kpro_resp}

      assert_raise Forklift.TopicManager.Error, "Something else went wrong", fn ->
        Forklift.TopicManager.create_and_subscribe("bob")
      end
    end

    test "raises response when error tuple received from kpro:request_sync" do
      allow :kpro.connect_controller(any(), any()), return: {:ok, :connection}
      allow :kpro.request_sync(any(), any(), any()), return: {:error, "bad request"}

      assert_raise Forklift.TopicManager.Error, "bad request", fn ->
        Forklift.TopicManager.create_and_subscribe("bob")
      end

      assert_called :kpro.close_connection(:connection)
    end

    test "raises error when there are connection issues with Kafka" do
      allow :kpro.connect_controller(any(), any()), return: {:error, "unexplained error"}

      assert_raise Forklift.TopicManager.Error, "unexplained error", fn ->
        Forklift.TopicManager.create_and_subscribe("bob")
      end

      refute_called :kpro.close_connection(any())
    end

    test "waits for topic to be created before continuing" do
      kpro_resp =
        {:kpro_rsp, :does_not_matter, :create_topics, 2,
         %{
           throttle_time_ms: 0,
           topic_errors: [
             %{
               error_code: :no_error,
               error_message: "Nothing went wrong",
               topic: "our_topic"
             }
           ]
         }}

      allow :kpro.connect_controller(any(), any()), return: {:ok, :connection}
      allow :kpro.request_sync(any(), any(), any()), return: {:ok, kpro_resp}

      none = {:ok, %{}}

      topic_metadata =
        {:ok,
         %{
           topic_metadata: [
             %{
               topic: "our_topic"
             }
           ]
         }}

      allow :brod.get_metadata(any(), :all), seq: [none, none, none, topic_metadata]
      allow Kaffe.GroupManager.subscribe_to_topics(any()), return: {:ok, ["our_topic"]}

      assert {:ok, ["our_topic"]} == Forklift.TopicManager.create_and_subscribe("our_topic")
      assert_called :brod.get_metadata(any(), :all), times(4)
      assert_called Kaffe.GroupManager.subscribe_to_topics(["our_topic"]), once()
    end
  end
end
