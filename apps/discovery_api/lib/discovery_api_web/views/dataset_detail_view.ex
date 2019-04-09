defmodule DiscoveryApiWeb.DatasetDetailView do
  @moduledoc false
  use DiscoveryApiWeb, :view

  def render("fetch_dataset_detail.json", %{dataset: dataset}) do
    transform_dataset_detail(dataset)
  end

  defp transform_dataset_detail(dataset) do
    %{
      name: dataset.title,
      description: dataset.description,
      id: dataset.id,
      keywords: dataset.keywords,
      organization: %{
        name: dataset.organizationDetails.orgTitle,
        image: dataset.organizationDetails.logoUrl,
        description: dataset.organizationDetails.description,
        homepage: dataset.organizationDetails.homepage
      },
      sourceType: dataset.sourceType,
      sourceUrl: dataset.sourceUrl,
      lastUpdatedDate: dataset.lastUpdatedDate
    }
  end
end
