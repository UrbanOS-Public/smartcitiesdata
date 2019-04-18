defmodule DiscoveryApi.Data.DatasetDetailsHandler do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset, as: DiscoveryDataset
  alias SmartCity.Organization

  def process_dataset_details_event(%SmartCity.Dataset{} = dataset) do
    case Organization.get(dataset.technical.orgId) do
      {:ok, organization} ->
        DiscoveryDataset.save(%DiscoveryDataset{
          id: dataset.id,
          title: dataset.business.dataTitle,
          name: dataset.technical.dataName,
          systemName: dataset.technical.systemName,
          keywords: dataset.business.keywords,
          organization: organization.orgTitle,
          organizationDetails: organization,
          modified: dataset.business.modifiedDate,
          description: dataset.business.description,
          fileTypes: get_file_type(dataset.technical.sourceFormat),
          sourceFormat: dataset.technical.sourceFormat,
          sourceType: dataset.technical.sourceType,
          sourceUrl: dataset.technical.sourceUrl,
          private: dataset.technical.private,
          contactName: dataset.business.contactName,
          contactEmail: dataset.business.contactEmail,
          license: dataset.business.license,
          rights: dataset.business.rights,
          homepage: dataset.business.homepage,
          spatial: dataset.business.spatial,
          temporal: dataset.business.temporal,
          publishFrequency: dataset.business.publishFrequency,
          conformsToUri: dataset.business.conformsToUri,
          describedByUrl: dataset.business.describedByUrl,
          describedByMimeType: dataset.business.describedByMimeType,
          parentDataset: dataset.business.parentDataset,
          issuedDate: dataset.business.issuedDate,
          language: dataset.business.language,
          referenceUrls: dataset.business.referenceUrls,
          categories: dataset.business.categories
        })

      error ->
        error
    end
  end

  defp get_file_type(source_format) do
    upcase_source_format = String.upcase(source_format)

    case upcase_source_format do
      "GTFS" -> ["JSON"]
      _everything_else -> [upcase_source_format]
    end
  end
end
