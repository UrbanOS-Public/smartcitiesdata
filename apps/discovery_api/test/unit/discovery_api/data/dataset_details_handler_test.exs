defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.Dataset

  test "maps a RegistryMessage to a Dataset" do
    event = %SmartCity.Dataset{
      id: "erin",
      business: %{
        dataTitle: "my title",
        description: "description",
        keywords: ["key", "words"],
        orgTitle: "publisher",
        modifiedDate: "timestamp"
      },
      technical: %{
        systemName: "foo__bar_baz"
        sourceUrl: "http://example.com",
        sourceType: "remote"
      }
    }

    expected = %Dataset{
      id: "erin",
      title: "my title",
      systemName: "foo__bar_baz",
      keywords: ["key", "words"],
      organization: "publisher",
      modified: "timestamp",
      description: "description",
      fileTypes: ["CSV"],
      system_name: "bob",
      sourceUrl: "http://example.com",
      sourceType: "remote"
    }

    expect(Dataset.save(expected), return: {:ok, "OK"})
    DatasetDetailsHandler.process_dataset_details_event(event)
  end
end
