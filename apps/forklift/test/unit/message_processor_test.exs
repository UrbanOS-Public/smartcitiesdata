defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageAccumulator
  alias Forklift.MessageProcessor

  test "data messages are routed to the appropriate processor" do
    dataset_id = Faker.StarWars.planet()
    payload = %{id: :rand.uniform(999), name: Faker.Superhero.name()}

    data_messages =
      payload
      |> Helper.make_data_message!(dataset_id)
      |> Helper.make_kafka_message("streaming-transformed")
      |> List.wrap()

    expect(MessageAccumulator.start_link(dataset_id), return: {:ok, :pid_placeholder})
    expect(MessageAccumulator.send_message(:pid_placeholder, payload), return: :ok)

    assert MessageProcessor.handle_messages(data_messages) == :ok
  end

  test "registry messages return {:ok, :no_commit}" do
    registry_message =
      Faker.StarWars.planet()
      |> Helper.make_registry_message()
      |> Helper.make_kafka_message("dataset-registry")
      |> List.wrap()

    assert MessageProcessor.handle_messages(registry_message) == {:ok, :no_commit}
  end
end
