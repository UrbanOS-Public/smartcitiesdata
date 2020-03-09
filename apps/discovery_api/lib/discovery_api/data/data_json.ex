defmodule DiscoveryApi.Data.DataJson do
  @moduledoc false
  alias DiscoveryApi.Data.Model

  def translate_to_open_data_schema() do
    models =
      Model.get_all()
      |> Enum.filter(&is_public?/1)
      |> Enum.reject(&is_remote?/1)

    %{
      conformsTo: "https://project-open-data.cio.gov/v1.1/schema",
      "@context": "https://project-open-data.cio.gov/v1.1/schema/catalog.jsonld",
      dataset: Enum.map(models, &translate_to_open_dataset/1)
    }
  end

  defp translate_to_open_dataset(%Model{} = model) do
    %{
      "@type" => "dcat:Dataset",
      "identifier" => model.id,
      "title" => model.title,
      "description" => model.description,
      "keyword" => val_or_optional(model.keywords),
      "modified" => model.modifiedDate,
      "publisher" => %{
        "@type" => "org:Organization",
        "name" => model.organization
      },
      "contactPoint" => %{
        "@type" => "vcard:Contact",
        "fn" => model.contactName,
        "hasEmail" => "mailto:" <> model.contactEmail
      },
      "accessLevel" => model.accessLevel,
      "license" => val_or_optional(model.license),
      "rights" => val_or_optional(model.rights),
      "spatial" => val_or_optional(model.spatial),
      "temporal" => :optional,
      "distribution" => [
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{DiscoveryApiWeb.Endpoint.url()}/api/v1/dataset/#{model.id}/download?_format=json",
          "mediaType" => "application/json"
        },
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{DiscoveryApiWeb.Endpoint.url()}/api/v1/dataset/#{model.id}/download?_format=csv",
          "mediaType" => "text/csv"
        }
      ],
      "accrualPeriodicity" => :optional,
      "conformsTo" => val_or_optional(model.conformsToUri),
      "describedBy" => val_or_optional(model.describedByUrl),
      "describedByType" => val_or_optional(model.describedByMimeType),
      "isPartOf" => val_or_optional(model.parentDataset),
      "issued" => val_or_optional(model.issuedDate),
      "language" => [val_or_optional(model.language)],
      "landingPage" => val_or_optional(model.homepage),
      "references" => val_or_optional(model.referenceUrls),
      "theme" => val_or_optional(model.categories)
    }
    |> remove_optional_values()
  end

  defp remove_optional_values(map) do
    map
    |> Enum.filter(fn {_key, value} ->
      value != :optional
    end)
    |> Enum.filter(fn {_key, value} ->
      value != [:optional]
    end)
    |> Enum.into(Map.new())
  end

  defp val_or_optional(""), do: :optional
  defp val_or_optional(nil), do: :optional
  defp val_or_optional(val), do: val

  defp is_public?(%Model{} = model) do
    model.private == false
  end

  defp is_remote?(%Model{} = model) do
    model.sourceType == "remote"
  end
end
