defmodule Dlq.ServerTest do
  use ExUnit.Case
  import Mock

  require Temp.Env

  # Setup the test environment variables
  Temp.Env.modify([
    %{
      app: :dlq,
      key: Dlq.Server,
      set: [
        endpoints: :endpoints,
        topic: :topic
      ]
    }
  ])

  test "will create topic if it does not exist" do
    with_mocks([
      {Elsa, [], [
        topic?: fn _, _ -> false end,
        create_topic: fn _, _ -> :ok end,
        produce: fn _, _, _ -> :ok end
      ]},
      {Elsa.Supervisor, [], [
        start_link: fn _ -> {:ok, :pid} end
      ]}
    ]) do
      start_supervised(Dlq.Server)
      Process.sleep(100) # Give the server time to start
      
      assert called(Elsa.topic?(:endpoints, :topic))
      assert called(Elsa.create_topic(:endpoints, :topic))
    end
  end

  test "starts elsa producer" do
    with_mocks([
      {Elsa, [], [
        topic?: fn _, _ -> true end,
        produce: fn _, _, _ -> :ok end
      ]},
      {Elsa.Supervisor, [], [
        start_link: fn opts ->
          assert opts == [
            endpoints: :endpoints,
            connection: :elsa_dlq,
            producer: [topic: :topic]
          ]
          {:ok, :pid}
        end
      ]}
    ]) do
      start_supervised(Dlq.Server)
      Process.sleep(100) # Give the server time to start
      
      assert called(Elsa.Supervisor.start_link(:_))
    end
  end

  test "write will jason encode dead letters and send to elsa" do
    messages = [
      %{"one" => 1},
      %{"two" => 2}
    ]
    
    expected = Enum.map(messages, &Jason.encode!/1)
    
    with_mocks([
      {Elsa, [], [
        topic?: fn _, _ -> true end,
        produce: fn conn, topic, msgs ->
          assert conn == :elsa_dlq
          assert topic == :topic
          assert msgs == expected
          :ok
        end
      ]},
      {Elsa.Supervisor, [], [
        start_link: fn _ -> {:ok, :pid} end
      ]}
    ]) do
      start_supervised(Dlq.Server)
      Process.sleep(100) # Give the server time to start
      
      Dlq.write(messages)
      Process.sleep(100) # Give the server time to process
      
      assert called(Elsa.produce(:elsa_dlq, :topic, expected))
    end
  end
end