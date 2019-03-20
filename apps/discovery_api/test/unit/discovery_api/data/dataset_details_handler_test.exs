defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.Dataset

  test "maps a RegistryMessage to a Dataset" do
    event = %SCOS.RegistryMessage{
      id: "erin",
      business: %{
        dataTitle: "my title",
        description: "description",
        keywords: ["key", "words"],
        orgTitle: "publisher",
        modifiedDate: "timestamp"
      },
      technical: %{
        systemName: "bob"
      }
    }

    expected = %Dataset{
      id: "erin",
      title: "my title",
      keywords: ["key", "words"],
      organization: "publisher",
      modified: "timestamp",
      description: "description",
      fileTypes: ["CSV"],
      system_name: "bob"
    }

    expect(Dataset.save(expected), return: {:ok, "OK"})
    DatasetDetailsHandler.process_dataset_details_event(event)
  end
end
