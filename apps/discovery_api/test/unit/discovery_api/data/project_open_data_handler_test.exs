defmodule DiscoveryApi.Data.ProjectOpenDataHandlerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.ProjectOpenDataHandler

  test "saves project open data to redis" do
    registry_message = %SCOS.RegistryMessage{
      id: "myfancydata",
      business: %{
        dataTitle: "my title",
        description: "description",
        modifiedDate: "The Date",
        orgTitle: "Organization 1",
        contactName: "Bob Jones",
        contactEmail: "bjones@example.com",
        license: "http://openlicense.org",
        keywords: ["key", "words"]
      }
    }

    podms_json_string =
      Jason.encode!(%{
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
            "accessURL" => "https://discoveryapi.tests.example.com/api/v1/#{registry_message.id}/download?_format=json",
            "mediaType" => "application/json"
          },
          %{
            "@type" => "dcat:Distribution",
            "accessURL" => "https://discoveryapi.tests.example.com/api/v1/#{registry_message.id}/download?_format=csv",
            "mediaType" => "text/csv"
          }
        ]
      })

    expect(
      Redix.command(:redix, [
        "SET",
        "discovery-api:project-open-data:#{registry_message.id}",
        podms_json_string
      ]),
      return: {:ok, "OK"}
    )

    ProjectOpenDataHandler.process_project_open_data_event(registry_message)
  end
end
