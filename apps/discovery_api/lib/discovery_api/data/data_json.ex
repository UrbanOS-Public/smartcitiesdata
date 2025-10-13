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
      "license" => ensure_valid_uri(model.license),
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
      "conformsTo" => ensure_valid_uri(model.conformsToUri),
      "describedBy" => ensure_valid_uri(model.describedByUrl),
      "describedByType" => val_or_optional(model.describedByMimeType),
      "isPartOf" => val_or_optional(model.parentDataset),
      "issued" => val_or_optional(model.issuedDate),
      "language" => [val_or_optional(model.language)],
      "landingPage" => ensure_valid_uri(model.homepage),
      "references" => ensure_valid_uri_array(model.referenceUrls),
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

  defp val_or_optional(nil), do: :optional
  defp val_or_optional(""), do: :optional

  defp val_or_optional(val) when is_binary(val) do
    case String.trim(val) do
      "" -> :optional
      trimmed -> trimmed
    end
  end

  defp val_or_optional(val), do: val

  # Helper to ensure URLs are valid URIs with schemes
  defp ensure_valid_uri(nil), do: :optional
  defp ensure_valid_uri(""), do: :optional

  defp ensure_valid_uri(val) when is_binary(val) do
    trimmed = String.trim(val)

    case URI.parse(trimmed) do
      # No scheme means invalid URI
      %URI{scheme: nil} -> :optional
      # Has scheme, valid URI
      %URI{scheme: _} -> trimmed
    end
  end

  defp ensure_valid_uri(_), do: :optional

  # Helper to ensure an array of URLs contains only valid URIs
  defp ensure_valid_uri_array(nil), do: :optional
  defp ensure_valid_uri_array([]), do: :optional

  defp ensure_valid_uri_array(list) when is_list(list) do
    valid_uris =
      Enum.filter(list, fn item ->
        case ensure_valid_uri(item) do
          :optional -> false
          _ -> true
        end
      end)

    case valid_uris do
      [] -> :optional
      uris -> uris
    end
  end

  defp ensure_valid_uri_array(_), do: :optional

  defp is_public?(%Model{} = model) do
    model.private == false
  end

  defp is_remote?(%Model{} = model) do
    model.sourceType == "remote"
  end
end
