defmodule Andi.Harvest.DataJsonToDataset do

  def mapper(%{"dataset" => datasets}) do
    Enum.map(datasets, &(dataset_model/1))
  end

  defp dataset_model(data_json_dataset) do
    %{
      "business" => %{
        "categories" => data_json_dataset["theme"],
        "conformsToUri" => "https://project-open-data.cio.gov/v1.1/schema/",
        "contactEmail" => Map.get(data_json_dataset["contactPoint"], :hasEmail),
        "contactName" => Map.get(data_json_dataset["contactPoint"], :fn),
        "dataTitle" => data_json_dataset["title"],
        "describedByMimeType" => data_json_dataset["describedByType"],
        "describedByUrl" => data_json_dataset["describedBy"],
        "description" => data_json_dataset["description"],
        "homepage" => data_json_dataset["landingPage"],
        "issuedDate" => data_json_dataset["issued"],
        "keywords" => data_json_dataset["keyword"],
        "language" => data_json_dataset["language"],
        "license" => data_json_dataset["license"],
        "modifiedDate" => data_json_dataset["modified"],
        "orgTitle" => "somethingrandom", # this will get injected elsewhere
        "parentDataset" => data_json_dataset["isPartOf"],
        "referenceUrls" => data_json_dataset["references"],
        "rights" => data_json_dataset["rights"],
        "spatial" => data_json_dataset["spatial"]
      },
      "id" => data_json_dataset["identifier"],
      "technical" => %{
        "dataName" => "Something random", # this is wrong for now
        "orgName" => "something", # this will get injected elsewhere
        "sourceFormat" => "text/html", # is this right?
        "private" => access_level(data_json_dataset["accessLevel"]),
        "sourceType" => "remote",
        "sourceUrl" => source_url(data_json_dataset["distribution"]),
        "systemName" => "somesysname" # this is wrong for now
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
end
