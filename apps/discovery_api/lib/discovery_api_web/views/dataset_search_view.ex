defmodule DiscoveryApiWeb.DatasetSearchView do
  @moduledoc """
  View for rendering dataset search results
  """
  use DiscoveryApiWeb, :view
  alias DiscoveryApi.Data.Model

  def render("search_dataset_summaries.json", %{
        models: models,
        facets: facets,
        sort: sort_by,
        offset: offset,
        limit: limit
      }) do
    datasets =
      models
      |> sort_models(sort_by)
      |> Enum.map(&translate_to_dataset/1)

    paginated_datasets = paginate(datasets, offset, limit)

    %{
      "metadata" => %{
        "totalDatasets" => Enum.count(datasets),
        "facets" => facets,
        "limit" => limit,
        "offset" => offset
      },
      "results" => paginated_datasets
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
      modified: model.modifiedDate,
      fileTypes: model.fileTypes,
      description: model.description,
      sourceType: model.sourceType,
      sourceUrl: model.sourceUrl,
      lastUpdatedDate: model.lastUpdatedDate
    }
  end

  defp sort_models(models, "name_asc") do
    Enum.sort_by(models, fn map -> String.downcase(map.title) end)
  end

  defp sort_models(models, "name_desc") do
    Enum.sort_by(models, fn map -> String.downcase(map.title) end, &>=/2)
  end

  defp sort_models(models, "last_mod") do
    Enum.sort_by(models, fn map -> map.modifiedDate end, &>=/2)
  end

  defp paginate(models, offset, limit) do
    Enum.slice(models, offset, limit)
  end
end
