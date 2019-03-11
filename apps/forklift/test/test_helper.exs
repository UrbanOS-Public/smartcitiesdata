Application.ensure_all_started(:logger)
Application.ensure_all_started(:placebo)

children = [{Registry, keys: :unique, name: Forklift.Registry}]
opts = [strategy: :one_for_one, name: Forklift.Supervisor]
Supervisor.start_link(children, opts)

ExUnit.start()
Faker.start()

defmodule Helper do
  def make_kafka_message(value, topic) do
    %{
      topic: topic,
      value: value |> Jason.encode!()
    }
  end

  def make_registry_message(dataset_id) do
    %SCOS.RegistryMessage{
      id: dataset_id,
      business: %{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "timestamp",
        orgTitle: "publisher",
        contactName: "Joe",
        contactEmail: "joe@none.com",
        license: "MIT"
      },
      technical: %{
        dataName: "name",
        orgName: "org name",
        systemName: "sys",
        stream: false,
        sourceUrl: "http://none.dev",
        sourceFormat: "gtfs",
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
  end

  def make_data_message!(payload, dataset_id) do
    {:ok, data_message} =
      SCOS.DataMessage.new(%{
        dataset_id: dataset_id,
        payload: payload,
        _metadata: %{org: "something", name: "else", stream: false},
        operational: %{timing: []}
      })

    data_message
  end
end
