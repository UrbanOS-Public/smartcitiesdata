defmodule DiscoveryApi.Data.ProjectOpenDataHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Persistence
  @name_space "discovery-api:project-open-data:"

  @base_url Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:host]

  def process_project_open_data_event(registry_message) do
    podms_map = %{
      "@type" => "dcat:Dataset",
      "title" => registry_message.business.dataTitle,
      "description" => registry_message.business.description,
      "keyword" => registry_message.business.keywords,
      "modified" => registry_message.business.modifiedDate,
      "publisher" => %{
        "@type" => "org:Organization",
        "name" => registry_message.business.orgTitle
      },
      "contactPoint" => %{
        "@type" => "vcard:Contact",
        "fn" => registry_message.business.contactName,
        "hasEmail" => "mailto:" <> registry_message.business.contactEmail
      },
      "identifier" => registry_message.id,
      "accessLevel" => "public",
      "distribution" => [
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "https://#{@base_url}/api/v1/#{registry_message.id}/download?_format=json",
          "mediaType" => "application/json"
        },
        %{
          "@type" => "dcat:Distribution",
          "accessURL" => "https://#{@base_url}/api/v1/#{registry_message.id}/download?_format=csv",
          "mediaType" => "text/csv"
        }
      ]
    }

    Persistence.persist(@name_space <> registry_message.id, podms_map)
  end
end
