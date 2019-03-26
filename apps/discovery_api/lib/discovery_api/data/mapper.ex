defmodule DiscoveryApi.Data.Mapper do
  @moduledoc """
  Map data from one thing to another
  """

  alias SmartCity.Dataset

  @doc """
  Map a `SmartCity.Dataset` to Project Open Metadata Schema format
  """
  def to_podms(%Dataset{business: business} = dataset, base_url) do
    %{
      "@type" => "dcat:Dataset",
      "title" => business.dataTitle,
      "description" => business.description,
      "keyword" => business.keywords,
      "modified" => business.modifiedDate,
      "publisher" => %{
        "@type" => "org:Organization",
        "name" => business.orgTitle
      },
      "contactPoint" => %{
        "@type" => "vcard:Contact",
        "fn" => business.contactName,
        "hasEmail" => "mailto:" <> business.contactEmail
      },
      "identifier" => dataset.id,
      "accessLevel" => "public",
      "license" => val_or_optional(business.license),
      "rights" => val_or_optional(business.rights),
      "spatial" => val_or_optional(business.spatial),
      "temporal" => val_or_optional(business.temporal),
      "distribution" => [
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{base_url}/api/v1/#{dataset.id}/download?_format=json",
          "mediaType" => "application/json"
        },
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "#{base_url}/api/v1/#{dataset.id}/download?_format=csv",
          "mediaType" => "text/csv"
        }
      ],
      "accrualPeriodicity" => val_or_optional(business.publishFrequency),
      "conformsTo" => val_or_optional(business.conformsToUri),
      "describedBy" => val_or_optional(business.describedByUrl),
      "describedByType" => val_or_optional(business.describedByMimeType),
      "isPartOf" => val_or_optional(business.parentDataset),
      "issued" => val_or_optional(business.issuedDate),
      "language" => val_or_optional(business.language),
      "landingPage" => val_or_optional(business.homepage),
      "references" => val_or_optional(business.referenceUrls),
      "theme" => val_or_optional(business.categories)
    }
    |> remove_optional_values()
  end

  defp remove_optional_values(map) do
    map
    |> Enum.filter(fn {_key, value} ->
      value != :optional
    end)
    |> Enum.into(Map.new())
  end

  defp val_or_optional(nil), do: :optional
  defp val_or_optional(val), do: val
end
