defmodule DiscoveryApi.Data.DatasetEventListenerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetEventListener
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.ProjectOpenDataHandler

  test "handle_message should pass RegistryMessage to handlers" do
    registry_message = create_registry_message("123")

    expect(DatasetDetailsHandler.process_dataset_details_event(registry_message), return: {:ok, "OK"})
    expect(ProjectOpenDataHandler.process_project_open_data_event(registry_message), return: {:ok, "OK"})

    DatasetEventListener.handle_message(create_kafka_event(registry_message))
  end

  test "handle_message should return :ok when successful" do
    registry_message = create_registry_message("123")
    allow(DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"})
    allow(ProjectOpenDataHandler.process_project_open_data_event(any()), return: {:ok, "OK"})

    response = DatasetEventListener.handle_message(create_kafka_event(registry_message))

    assert response == :ok
  end

  @tag capture_log: true
  test "handle_message should return :ok and log when Process Dataset Details fails" do
    registry_message = create_registry_message("123")

    allow(DatasetDetailsHandler.process_dataset_details_event(any()),
      return: {:error, %Redix.Error{message: "ERR wrong number of arguments for 'set' command"}}
    )

    allow(ProjectOpenDataHandler.process_project_open_data_event(any()), return: {:ok, "OK"})

    response = DatasetEventListener.handle_message(create_kafka_event(registry_message))

    assert response == :ok
  end

  @tag capture_log: true
  test "handle_message should return :ok and log when Process project open data fails" do
    registry_message = create_registry_message("123")

    allow(DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"})

    allow(ProjectOpenDataHandler.process_project_open_data_event(any()),
      return: {:error, %Redix.Error{message: "ERR wrong number of arguments for 'set' command"}}
    )

    response = DatasetEventListener.handle_message(create_kafka_event(registry_message))

    assert response == :ok
  end

  defp create_registry_message(id) do
    %SCOS.RegistryMessage{
      id: id,
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
        sourceFormat: "gtfs"
      }
    }
  end

  defp create_kafka_event(event) do
    event
    |> Jason.encode!()
    |> (fn encoded_json -> %{key: "message", value: encoded_json} end).()
  end
end
