defmodule ForkliftTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageProcessor

  test "data messages are processed to Prestige" do
    allow(Prestige.execute(any(), catalog: "hive", schema: "default", user: "foobar"), return: :ok)

    allow(Prestige.prefetch(any()), return: [])

    dataset_id = Faker.StarWars.planet()
    message = make_message(dataset_id)
    _expected = message |> Map.get(:value) |> Jason.decode!() |> Map.get("payload")

    dataset_id
    |> make_schema_message()
    |> List.wrap()
    |> MessageProcessor.handle_messages()

    MessageProcessor.handle_messages([message])

    expected_statement = ~s/insert into #{dataset_id} (id,name) values (111,'bob')/

    assert_called(
      Prestige.execute(expected_statement, catalog: "hive", schema: "default", user: "foobar"),
      once()
    )
  end

  def make_message(dataset_id, topic \\ "streaming-transformed") do
    value =
      %{
        payload: %{id: 111, name: "bob"},
        metadata: %{dataset_id: dataset_id}
      }
      |> Jason.encode!()

    %{
      topic: topic,
      value: value
    }
  end

  defp dataset_registry_topic do
    Application.get_env(:forklift, :registry_topic)
  end

  defp make_schema_message(dataset_id, topic \\ dataset_registry_topic()) do
    payload = %{
      "id" => dataset_id,
      "operational" => %{
        "schema" => [
          %{
            "name" => "id",
            "type" => "int"
          },
          %{
            "name" => "name",
            "type" => "string"
          }
        ]
      }
    }

    %{
      topic: topic,
      value: Jason.encode!(payload)
    }
  end
end
