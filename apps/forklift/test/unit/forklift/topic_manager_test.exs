defmodule Forklift.TopicManagerTest do
  use ExUnit.Case
  use Placebo

  describe "create/1" do
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

      allow :kpro.connect_any(any(), any()), return: {:ok, :does_not_matter}
      allow :kpro.request_sync(any(), any(), any()), return: {:ok, kpro_resp}

      assert_raise Forklift.TopicManager.Error, "Something else went wrong", fn ->
        Forklift.TopicManager.create("bob")
      end
    end

    test "raises response when error tuple received from kpro:request_sync" do
      allow :kpro.connect_any(any(), any()), return: {:ok, :connection}
      allow :kpro.request_sync(any(), any(), any()), return: {:error, "bad request"}

      assert_raise Forklift.TopicManager.Error, "bad request", fn ->
        Forklift.TopicManager.create("bob")
      end

      assert_called :kpro.close_connection(:connection)
    end

    test "raises error when there are connection issues with Kafka" do
      allow :kpro.connect_any(any(), any()), return: {:error, "unexplained error"}

      assert_raise Forklift.TopicManager.Error, "unexplained error", fn ->
        Forklift.TopicManager.create("bob")
      end

      refute_called :kpro.close_connection(any())
    end
  end
end
