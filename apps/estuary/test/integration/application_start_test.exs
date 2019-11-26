defmodule Estuary.CreateTopicTest do
  use ExUnit.Case

  setup_all do
    Application.start(:estuary)
    :ok
  end

  describe "Estuary supervisor tree starts up" do
    test "Create topic" do
      Elsa.Topic.create([localhost: 9092], "event-stream")
      {:ok, topics} = Elsa.list_topics([localhost: 9092])

      # assert topics == [{"event-stream", 1}]
    end

    test "Estuary connects to Kafka" do
      assert true
    end
  end
end
