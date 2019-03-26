defmodule DiscoveryApi.Data.ProjectOpenDataHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.ProjectOpenDataHandler

  setup do
    dataset = %SmartCity.Dataset{
      id: "myfancydata",
      business: %SmartCity.Dataset.Business{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "The Date",
        orgTitle: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "http://openlicense.org",
        keywords: ["key", "words"],
        homepage: "www.bad.com"
      }
    }

    {:ok,
     %{
       dataset: dataset
     }}
  end

  test "saves project open data to redis", %{dataset: dataset} do
    expect(
      Redix.command(:redix, [
        "SET",
        "discovery-api:project-open-data:#{dataset.id}",
        any()
      ]),
      return: {:ok, "OK"}
    )

    ProjectOpenDataHandler.process_project_open_data_event(dataset)
  end
end
