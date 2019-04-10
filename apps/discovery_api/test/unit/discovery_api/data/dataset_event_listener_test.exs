defmodule DiscoveryApi.Data.DatasetEventListenerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetEventListener
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.ProjectOpenDataHandler
  alias DiscoveryApi.Data.SystemNameCache
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    allow SmartCity.Organization.get(any()), return: {:error, :not_found}, meck_options: [:passthrough]
    :ok
  end

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

  test "handle_dataset create orgName/dataName mapping to dataset_id" do
    org = TDG.create_organization(id: "org1")
    dataset = TDG.create_dataset(id: "ds1", technical: %{orgId: org.id})
    allow SmartCity.Organization.get("org1"), return: {:ok, org}
    allow DatasetDetailsHandler.process_dataset_details_event(any()), return: {:ok, "OK"}
    allow ProjectOpenDataHandler.process_project_open_data_event(any()), return: {:ok, "OK"}

    DatasetEventListener.handle_dataset(dataset)

    assert SystemNameCache.get(org.orgName, dataset.technical.dataName) == "ds1"
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
        orgId: "org_id",
        orgName: "org_name",
        systemName: "sys",
        stream: false,
        sourceUrl: "http://none.dev",
        sourceFormat: "gtfs"
      }
    }
  end
end
