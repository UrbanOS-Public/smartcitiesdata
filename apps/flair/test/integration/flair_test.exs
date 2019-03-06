defmodule FlairTest do
  use ExUnit.Case
  use Divo.Integration
  use Placebo
  alias SCOS.DataMessage.Timing

  doctest Flair

  setup _ do
    messages =
      [
        %{
          "payload" => %{"name" => "Jack Sparrow"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        },
        %{
          "payload" => %{"name" => "Will Turner"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        },
        %{
          "payload" => %{"name" => "Barbosa"},
          "_metadata" => %{},
          "dataset_id" => "pirates",
          "operational" => %{"timing" => [timing()]}
        }
      ]
      |> Enum.map(&Jason.encode!/1)

    [messages: messages]
  end

  test "flair consumes messages and calls out to presto", context do
    allow(Flair.PrestoClient.execute(any()), return: [])
    allow(Flair.PrestoClient.generate_statement_from_events(any()), return: "")
    Mockaffe.send_to_kafka(context[:messages], "streaming-validated")

    Patiently.wait_for!(
      &wait_for_function_call/0,
      dwell: 1000,
      max_tries: 10
    )
  end

  def wait_for_function_call() do
    try do
      assert_called(
        # TODO: Figure out how to Divo a presto environment to complete the integration test environment
        Flair.PrestoClient.execute(any()),
        once()
      )

      true
    rescue
      _ -> false
    end
  end

  defp timing() do
    start_time = Timing.current_time()
    Process.sleep(1)

    %{
      "start_time" => start_time,
      "end_time" => Timing.current_time(),
      "app" => :valkyrie,
      "label" => ""
    }
  end
end
