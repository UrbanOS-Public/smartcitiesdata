defmodule Reaper.ReaperConfigTest do
  @moduledoc false

  use ExUnit.Case
  use Placebo
  alias Reaper.ReaperConfig
  alias SCOS.RegistryMessage

  setup do
    map = %{
      "id" => "uuid",
      "technical" => %{
        "dataName" => "dataset",
        "orgName" => "org",
        "systemName" => "org__dataset",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceFormat" => "gtfs",
        "cadence" => 9000,
        "headers" => %{},
        "partitioner" => %{type: nil, query: nil},
        "queryParams" => %{},
        "transformations" => [],
        "validations" => [],
        "schema" => []
      },
      "business" => %{
        "dataTitle" => "dataset title",
        "description" => "description",
        "keywords" => ["one", "two"],
        "modifiedDate" => "date",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => ""
      }
    }

    map_missing = %{
      "id" => "uuid",
      "technical" => %{
        "dataName" => "dataset",
        "orgName" => "org",
        "systemName" => "org__dataset",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceFormat" => "gtfs",
        "cadence" => 9000,
        "headers" => %{},
        "partitioner" => nil,
        "queryParams" => %{},
        "transformations" => [],
        "validations" => [],
        "schema" => []
      },
      "business" => %{
        "dataTitle" => "dataset title",
        "description" => "description",
        "keywords" => ["one", "two"],
        "modifiedDate" => "date",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "license",
        "rights" => "rights information",
        "homepage" => ""
      }
    }

    json = Jason.encode!(map)
    {:ok, registry_message} = RegistryMessage.new(map)

    {:ok, map: map, map_missing: map_missing, registry_message: registry_message, json: json}
  end

  test "Successfully create ReaperConfig from Registry with valid partitioner", %{registry_message: registry_message} do
    {:ok, reaper_config} = ReaperConfig.from_registry_message(registry_message)

    assert reaper_config.dataset_id == "uuid"
    assert reaper_config.cadence == 9000
    assert reaper_config.sourceFormat == "gtfs"
    assert reaper_config.sourceUrl == "https://example.com"
    assert reaper_config.partitioner.type == nil
    assert reaper_config.partitioner.query == nil
    assert reaper_config.queryParams == %{}
  end

  test "Successfully fills in partitioner when registry message is missing partitioner", %{map_missing: map_missing} do
    {:ok, registry_message} = RegistryMessage.new(map_missing)
    {:ok, reaper_config} = ReaperConfig.from_registry_message(registry_message)

    assert reaper_config.dataset_id == "uuid"
    assert reaper_config.cadence == 9000
    assert reaper_config.sourceFormat == "gtfs"
    assert reaper_config.sourceUrl == "https://example.com"
    assert reaper_config.partitioner == nil
    assert reaper_config.queryParams == %{}
  end
end
