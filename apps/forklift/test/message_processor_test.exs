defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageAccumulator
  alias Forklift.MessageProcessor

  test "data messages are routed to the appropriate processor" do
    dataset_id = Faker.StarWars.planet()
    message = make_message(dataset_id)
    expected = message |> Map.get(:value) |> Jason.decode!() |> Map.get("payload")

    expect(MessageAccumulator.start_link(dataset_id), return: {:ok, :pid_placeholder})
    expect(MessageAccumulator.send_message(:pid_placeholder, expected), return: :ok)

    assert MessageProcessor.handle_messages([message]) == :ok
  end

  test "registry messages return :ok" do
    # This test should be expanded once we know more about how registry messages will work. -JP 02/08/18
    message = make_registry_message(Faker.StarWars.planet())



    assert MessageProcessor.handle_messages([message]) == :ok
  end

  def make_message(dataset_id, topic \\ "data-topic") do
    value =
      %{
        payload: %{id: :rand.uniform(999), name: Faker.Superhero.name()},
        metadata: %{dataset_id: dataset_id}
      }
      |> Jason.encode!()

    %{
      topic: topic,
      value: value
    }
  end

  def make_registry_message(dataset_id) do
    value =
      %{
        id: dataset_id,
        operational: %{
          schema: [
            %{
              name: "id",
              type: "int"
            },
            %{
              name: "name",
              type: "string"
            }
          ]
        }
      }
      |> Jason.encode!()

    %{
      topic: "dataset-registry",
      value: value
    }
  end
end
