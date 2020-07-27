defmodule Dlq.ServerTest do
  use ExUnit.Case
  use Placebo
  import AssertAsync
  require Temp.Env

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

  setup do
    allow Elsa.Supervisor.start_link(any()), return: {:ok, :elsa_pid}
    allow Elsa.topic?(any(), any()), return: true

    :ok
  end

  test "will create topic if it does not exist" do
    allow Elsa.topic?(any(), any()), return: false
    allow Elsa.create_topic(any(), any()), return: :ok

    start_supervised(Dlq.Server)

    assert_async do
      assert_called Elsa.topic?(:endpoints, :topic)
      assert_called Elsa.create_topic(:endpoints, :topic)
    end
  end

  test "will retry creating topic" do
    allow Elsa.topic?(any(), any()), return: false
    allow Elsa.create_topic(any(), any()), seq: [{:error, :bad_value}, :ok]

    start_supervised(Dlq.Server)

    assert_async do
      assert_called Elsa.topic?(:endpoints, :topic), times(2)
      assert_called Elsa.create_topic(:endpoints, :topic), times(2)
    end
  end

  test "starts elsa producer" do
    start_supervised({Dlq.Server, []})

    assert_async do
      assert_called Elsa.Supervisor.start_link(
                      endpoints: :endpoints,
                      connection: :elsa_dlq,
                      producer: [topic: :topic]
                    )
    end
  end

  test "will retry to start elsa supervisor" do
    allow Elsa.Supervisor.start_link(any()), seq: [{:error, :bad_thing}, {:ok, :elsa_pid}]

    start_supervised({Dlq.Server, []})

    assert_async do
      assert_called Elsa.Supervisor.start_link(
                      endpoints: :endpoints,
                      connection: :elsa_dlq,
                      producer: [topic: :topic]
                    ),
                    times(2)
    end
  end

  test "write will jason encode dead letters and send to elsa" do
    allow Elsa.produce(any(), any(), any()), return: :ok

    start_supervised({Dlq.Server, []})

    messages = [
      %{"one" => 1},
      %{"two" => 2}
    ]

    Dlq.write(messages)

    expected = Enum.map(messages, &Jason.encode!/1)

    assert_async do
      assert_called Elsa.produce(:elsa_dlq, :topic, expected)
    end
  end
end
