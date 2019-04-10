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
        name: dataset.organizationDetails.orgName,
        title: dataset.organizationDetails.orgTitle,
        image: dataset.organizationDetails.logoUrl,
        description: dataset.organizationDetails.description,
        homepage: dataset.organizationDetails.homepage
      },
      sourceType: dataset.sourceType,
      sourceUrl: dataset.sourceUrl,
      lastUpdatedDate: dataset.lastUpdatedDate,
      contactName: dataset.contactName,
      contactEmail: dataset.contactEmail,
      license: dataset.license,
      rights: dataset.rights,
      homepage: dataset.homepage,
      spatial: dataset.spatial,
      temporal: dataset.temporal,
      publishFrequency: dataset.publishFrequency,
      conformsToUri: dataset.conformsToUri,
      describedByUrl: dataset.describedByUrl,
      describedByMimeType: dataset.describedByMimeType,
      parentDataset: dataset.parentDataset,
      issuedDate: dataset.issuedDate,
      language: dataset.language,
      referenceUrls: dataset.referenceUrls,
      categories: dataset.categories,
      modified: dataset.modified
    }
  end
end
