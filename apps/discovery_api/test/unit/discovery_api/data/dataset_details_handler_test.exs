defmodule DiscoveryApi.Data.DatasetDetailsHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.DatasetDetailsHandler
  alias DiscoveryApi.Data.Dataset

  test "Schema is enforced" do
    event = %{
      "id" => "erin",
      "business" => %{
        "title" => "my title",
        "description" => "description",
        "keywords" => ["key", "words"],
        "publisher" => "publisher",
        "modified" => "timestamp"
      },
      "operational" => %{
        "fileTypes" => ["file", "types"]
      }
    }

    expected = %Dataset{
      id: "erin",
      title: "my title",
      keywords: ["key", "words"],
      organization: "publisher",
      modified: "timestamp",
      description: "description",
      fileTypes: ["file", "types"]
    }

    expect(Dataset.save(expected), return: {:ok, "OK"})
    DatasetDetailsHandler.process_dataset_details_event(event)
  end

  describe "process_dataset_details_event" do
    test "does not persist nested data when input fields are not maps" do
      event = %{
        "id" => "erin",
        "business" => 2,
        "operational" => 3
      }

      expected = %Dataset{
        id: "erin"
      }

      expect(Dataset.save(expected), return: {:ok, "OK"})
      DatasetDetailsHandler.process_dataset_details_event(event)
    end

    test "does not persist nested data when input top level field does not exist" do
      event = %{
        "id" => "erin"
      }

      expected = %Dataset{
        id: "erin"
      }

      expect(Dataset.save(expected), return: {:ok, "OK"})
      DatasetDetailsHandler.process_dataset_details_event(event)
    end
  end
end
