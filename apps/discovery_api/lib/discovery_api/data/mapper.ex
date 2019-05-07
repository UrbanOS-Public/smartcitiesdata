defmodule DiscoveryApi.Data.Mapper do
  @moduledoc """
  Map data from one thing to another
  """

  alias SmartCity.{Dataset, Organization}
  alias DiscoveryApi.Data.Model

  @doc """
  Map a `SmartCity.Dataset` to a `DiscoveryApi.Data.Model`
  """
  def to_data_model(%Dataset{} = dataset, %Organization{} = organization) do
    %Model{
      id: dataset.id,
      name: dataset.technical.dataName,
      title: dataset.business.dataTitle,
      keywords: dataset.business.keywords,
      modifiedDate: dataset.business.modifiedDate,
      fileTypes: get_file_type(dataset.technical.sourceFormat),
      description: dataset.business.description,
      systemName: dataset.technical.systemName,
      sourceUrl: dataset.technical.sourceUrl,
      sourceType: dataset.technical.sourceType,
      sourceFormat: dataset.technical.sourceFormat,
      private: dataset.technical.private,
      accessLevel: ternary(dataset.technical.private, "non-public", "public"),
      contactName: dataset.business.contactName,
      contactEmail: dataset.business.contactEmail,
      license:
        ternary(dataset.technical.private, dataset.business.license, "http://opendefinition.org/licenses/cc-by/"),
      rights: dataset.business.rights,
      homepage: dataset.business.homepage,
      spatial: dataset.business.spatial,
      temporal: dataset.business.temporal,
      publishFrequency: dataset.business.publishFrequency,
      conformsToUri: "https://project-open-data.cio.gov/v1.1/schema/",
      describedByUrl: dataset.business.describedByUrl,
      describedByMimeType: dataset.business.describedByMimeType,
      parentDataset: dataset.business.parentDataset,
      issuedDate: dataset.business.issuedDate,
      language: dataset.business.language,
      referenceUrls: dataset.business.referenceUrls,
      categories: dataset.business.categories,
      organization: organization.orgTitle,
      organizationDetails: %{
        id: organization.id,
        orgName: organization.orgName,
        orgTitle: organization.orgTitle,
        description: organization.description,
        logoUrl: organization.logoUrl,
        homepage: organization.homepage,
        dn: organization.dn
      }
    }
  end

  defp get_file_type(source_format) do
    upcase_source_format = String.upcase(source_format)

    case upcase_source_format do
      "GTFS" -> ["JSON"]
      _everything_else -> [upcase_source_format]
    end
  end

  defp ternary(condition, success, _failure) when condition, do: success
  defp ternary(_condition, _success, failure), do: failure
end
