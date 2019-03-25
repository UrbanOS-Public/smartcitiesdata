defmodule DiscoveryApi.Data.ProjectOpenDataHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Persistence
  @name_space "discovery-api:project-open-data:"

  def process_project_open_data_event(dataset) do
    base_url = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:host]

    podms_map = %{
      "@type" => "dcat:Dataset",
      "title" => dataset.business.dataTitle,
      "description" => dataset.business.description,
      "keyword" => dataset.business.keywords,
      "modified" => dataset.business.modifiedDate,
      "publisher" => %{
        "@type" => "org:Organization",
        "name" => dataset.business.orgTitle
      },
      "contactPoint" => %{
        "@type" => "vcard:Contact",
        "fn" => dataset.business.contactName,
        "hasEmail" => "mailto:" <> dataset.business.contactEmail
      },
      "identifier" => dataset.id,
      "accessLevel" => "public",
      "distribution" => [
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "https://discoveryapi.#{base_url}/api/v1/#{dataset.id}/download?_format=json",
          "mediaType" => "application/json"
        },
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "https://discoveryapi.#{base_url}/api/v1/#{dataset.id}/download?_format=csv",
          "mediaType" => "text/csv"
        }
      ]
    }

    Persistence.persist(@name_space <> dataset.id, podms_map)
  end
end
