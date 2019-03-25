defmodule DiscoveryApi.Data.DatasetEventListenerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetEventListener
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.ProjectOpenDataHandler

  test "handle_dataset should pass Dataset to handlers" do
    dataset = create_dataset("123")

    expect(DatasetDetailsHandler.process_dataset_details_event(dataset), return: {:ok, "OK"})
    expect(ProjectOpenDataHandler.process_project_open_data_event(dataset), return: {:ok, "OK"})

    DatasetEventListener.handle_dataset(dataset)
  end

  test "handle_dataset should return :ok when successful" do
    dataset = create_dataset("123")
    allow(DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"})
    allow(ProjectOpenDataHandler.process_project_open_data_event(any()), return: {:ok, "OK"})

    response = DatasetEventListener.handle_dataset(dataset)

    assert response == :ok
  end

  @tag capture_log: true
  test "handle_dataset should return :ok and log when Process Dataset Details fails" do
    dataset = create_dataset("123")

    allow(DatasetDetailsHandler.process_dataset_details_event(any()),
      return: {:error, %Redix.Error{message: "ERR wrong number of arguments for 'set' command"}}
    )

    allow(ProjectOpenDataHandler.process_project_open_data_event(any()), return: {:ok, "OK"})

    response = DatasetEventListener.handle_dataset(dataset)

    assert response == :ok
  end

  @tag capture_log: true
  test "handle_dataset should return :ok and log when Process project open data fails" do
    dataset = create_dataset("123")

    allow(DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"})

    allow(ProjectOpenDataHandler.process_project_open_data_event(any()),
      return: {:error, %Redix.Error{message: "ERR wrong number of arguments for 'set' command"}}
    )

    response = DatasetEventListener.handle_dataset(dataset)

    assert response == :ok
  end

  defp create_dataset(id) do
    %SmartCity.Dataset{
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
end
