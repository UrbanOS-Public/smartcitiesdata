defmodule DiscoveryApiWeb.DatasetDetailView do
  @moduledoc false
  use DiscoveryApiWeb, :view

  def render("fetch_dataset_detail.json", %{dataset: dataset, organization: organization}) do
    transform_dataset_detail(dataset, organization)
  end

  defp transform_dataset_detail(dataset, organization) do
    %{
      name: dataset.title,
      description: dataset.description,
      id: dataset.id,
      keywords: dataset.keywords,
      organization: %{
        name: organization.orgTitle,
        image: organization.logoUrl,
        description: organization.description,
        homepage: organization.homepage
      },
      sourceType: dataset.sourceType,
      sourceUrl: dataset.sourceUrl
    }
  end
end
