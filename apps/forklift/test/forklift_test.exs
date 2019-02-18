defmodule ForkliftTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageAccumulator
  alias Forklift.MessageProcessor

  test "data messages are processed to Prestige" do
    allow(Prestige.execute(any(), catalog: "hive", schema: "default"), return: :ok)
    allow(Prestige.prefetch(any()), return: [])

    dataset_id = Faker.StarWars.planet()
    message = make_message(dataset_id)
    expected = message |> Map.get(:value) |> Jason.decode!() |> Map.get("payload")

    MessageProcessor.handle_messages([message])

    expected_statement = ~s/insert into #{dataset_id} (id,name) values (111,'bob')/

    assert_called(
      Prestige.execute(expected_statement, catalog: "hive", schema: "default"),
      once()
    )
  end

  def make_message(dataset_id, topic \\ "data-topic") do
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
end
