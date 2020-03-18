defmodule DiscoveryApiWeb.MultipleMetadataView do
  use DiscoveryApiWeb, :view
  alias DiscoveryApi.Data.Model

  def accepted_formats() do
    ["json"]
  end

  def render("search_dataset_summaries.json", %{
        models: models,
        facets: facets,
        sort: sort_by,
        offset: offset,
        limit: limit
      }) do
    datasets =
      models
      |> DiscoveryApiWeb.Utilities.ModelSorter.sort_models(sort_by)
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

  def render("fetch_table_info.json", %{
        models: models
      }) do
    datasets =
      models
      |> Enum.map(&translate_to_dataset/1)

    %{
      "metadata" => %{
        "totalDatasets" => Enum.count(datasets)
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

  defp paginate(models, offset, limit) do
    Enum.slice(models, offset, limit)
  end
end
