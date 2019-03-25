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
        name: dataset.organization,
        image: "https://www.cota.com/wp-content/uploads/2016/04/COSI-Image-414x236.jpg"
      },
      sourceType: dataset.sourceType,
      sourceUrl: dataset.sourceUrl
    }
  end
end
