defmodule ForkliftTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.MessageProcessor

  # test "data messages are processed to Prestige" do
  #   dataset_id = Faker.UUID.v4()

  #   payload = %{
  #     id: :rand.uniform(999),
  #     name: Faker.StarWars.planet()
  #   }

  #   expected_statement = ~s/insert into #{dataset_id} (id,name) values (#{payload.id},'#{payload.name}')/
  #   expect(Prestige.execute(expected_statement), return: :ok)
  #   allow(Prestige.prefetch(any()), return: [])

  #   send_registry_message(dataset_id)
  #   send_data_message(payload, dataset_id)
  # end

  defp send_registry_message(dataset_id) do
    dataset_id
    |> Helper.make_registry_message()
    |> Helper.make_kafka_message("dataset-registry")
    |> List.wrap()
    |> MessageProcessor.handle_messages()
  end

  defp send_data_message(payload, dataset_id) do
    payload
    |> Helper.make_data_message!(dataset_id)
    |> Helper.make_kafka_message("streaming-transformed")
    |> List.wrap()
    |> MessageProcessor.handle_messages()
  end
end
