defmodule DiscoveryApiWeb.SearchView do
  use DiscoveryApiWeb, :view
  alias DiscoveryApi.Data.Model

  def accepted_formats() do
    ["json"]
  end

  def render("search_view.json", %{
        models: models,
        facets: facets,
        offset: offset,
        limit: limit,
        total: total
      }) do
    datasets =
      models
      |> Enum.map(&translate_to_dataset/1)

    %{
      "metadata" => %{
        "totalDatasets" => total,
        "facets" => facets,
        "limit" => limit,
        "offset" => offset
      },
      "results" => datasets
    }
  end

  defp translate_to_dataset(%Model{} = model) do
    %{
      id: model.id,
      name: model.name,
      title: model.title,
      keywords: model.keywords,
      systemName: model.systemName,
      organization_title: model.organizationDetails.orgTitle,
      organization_name: model.organizationDetails.orgName,
      organization_image_url: model.organizationDetails.logoUrl,
      modified: model.modifiedDate,
      fileTypes: model.fileTypes,
      description: model.description,
      sourceType: model.sourceType,
      sourceUrl: model.sourceUrl,
      lastUpdatedDate: model.lastUpdatedDate
    }
  end
end
