defmodule DiscoveryApi.Data.DatasetEventListenerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetEventListener
  alias DiscoveryApi.Data.DatasetDetailsHandler

  test "handle_message should pass business details to dataset detail handler" do
    event = create_event("123")
    expect(DatasetDetailsHandler.process_dataset_details_event(event), return: {:ok, "OK"})

    DatasetEventListener.handle_message(create_kafka_event(event))
  end

  test "handle_message should return :ok when successful" do
    event = create_event("123")
    allow(DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"})

    response = DatasetEventListener.handle_message(create_kafka_event(event))

    assert response == :ok
  end

  test "handle_message should return :error when failed" do
    event = create_event("123")

    allow(DatasetDetailsHandler.process_dataset_details_event(any()),
      return: {:error, %Redix.Error{message: "ERR wrong number of arguments for 'set' command"}}
    )

    response = DatasetEventListener.handle_message(create_kafka_event(event))

    assert response == :error
  end

  defp create_event(id) do
    %{
      "id" => id,
      "business" => %{"title" => "This is a great title"},
      "operational" => %{}
    }
  end

  defp create_kafka_event(event) do
    Jason.encode!(event)
    |> (fn encoded_json -> %{key: "message", value: encoded_json} end).()
  end
end
