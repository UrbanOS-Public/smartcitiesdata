defmodule Andi.Harvest.DataJsonDatasetMapper do
  @moduledoc """
  maps data json to %SmartCity.Dataset{}
  """
  alias Andi.InputSchemas.Datasets

  use Properties, otp_app: :andi

  getter(:dataset_name_max_length, generic: true)

  @scos_data_json_seed "1719bf64-38f5-40bf-9737-45e84f5c8419"

  def dataset_mapper(%{"dataset" => datasets}, org) do
    Enum.map(datasets, fn data_json_dataset -> dataset_model(data_json_dataset, org) end)
    |> Enum.filter(&is_public?/1)
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.reduce([], fn dataset, acc ->
      case SmartCity.Dataset.new(dataset) do
        {:ok, dataset} -> [dataset | acc]
        _ -> acc
      end
    end)
  end

  def harvested_dataset_mapper(%{"dataset" => datasets}, org) do
    Enum.map(datasets, fn data_json_dataset -> harvested_dataset_model(data_json_dataset, org) end)
  end

  defp harvested_dataset_model(data_json_dataset, org) do
    %{
      "orgId" => org.id,
      "sourceId" => data_json_dataset["identifier"],
      "systemId" => system_name(org.orgName, data_name(data_json_dataset["title"])),
      "source" => Map.get(data_json_dataset["publisher"], "source"),
      "modifiedDate" => modified_date(data_json_dataset["modified"]),
      "datasetId" => generate_scos_dataset_id(data_json_dataset["identifier"]),
      "include" => true,
      "dataTitle" => data_json_dataset["title"]
    }
  end

  defp dataset_model(data_json_dataset, org) do
    %{
      "business" => %{
        "categories" => data_json_dataset["theme"],
        "conformsToUri" => "https://project-open-data.cio.gov/v1.1/schema/",
        "contactEmail" => Map.get(data_json_dataset["contactPoint"], "hasEmail"),
        "contactName" => Map.get(data_json_dataset["contactPoint"], "fn"),
        "dataTitle" => data_json_dataset["title"],
        "describedByMimeType" => data_json_dataset["describedByType"],
        "describedByUrl" => data_json_dataset["describedBy"],
        "description" => data_json_dataset["description"],
        "homepage" => data_json_dataset["landingPage"],
        "issuedDate" => data_json_dataset["issued"],
        "keywords" => data_json_dataset["keyword"],
        "language" => data_json_dataset["language"],
        "license" => data_json_dataset["license"],
        "modifiedDate" => modified_date(data_json_dataset["modified"]),
        "orgTitle" => org.orgTitle,
        "parentDataset" => data_json_dataset["isPartOf"],
        "referenceUrls" => data_json_dataset["references"],
        "rights" => data_json_dataset["rights"],
        "spatial" => data_json_dataset["spatial"]
      },
      "id" => generate_scos_dataset_id(data_json_dataset["identifier"]),
      "technical" => %{
        "dataName" => data_name(data_json_dataset["title"]),
        "orgName" => org.orgName,
        "orgId" => org.id,
        "sourceFormat" => "text/html",
        "private" => access_level(data_json_dataset["accessLevel"]),
        "sourceType" => "remote",
        "sourceUrl" => source_url(data_json_dataset["distribution"]),
        "systemName" => system_name(org.orgName, data_name(data_json_dataset["title"]))
      }
    }
  end

  defp access_level(access_level) do
    case access_level do
      "non-public" -> true
      "public" -> false
      _ -> false
    end
  end

  defp source_url([%{"mediaType" => "text/html", "accessURL" => access_url} | _rest]) do
    access_url
  end

  defp source_url(_distribution), do: ""

  defp data_name(data_title) do
    Datasets.data_title_to_data_name(data_title, dataset_name_max_length())
  end

  defp system_name(org_name, data_name) do
    "#{org_name}__#{data_name}"
  end

  defp is_public?(dataset) do
    dataset["technical"]["private"] == false
  end

  defp modified_date(date) when is_nil(date) do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  defp modified_date(date), do: date

  defp generate_scos_dataset_id(identifier) do
    identifier = to_string(identifier)
    UUID.uuid5(@scos_data_json_seed, identifier)
  end
end
