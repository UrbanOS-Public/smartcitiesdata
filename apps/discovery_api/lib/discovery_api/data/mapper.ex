defmodule DiscoveryApi.Data.Mapper do
  @moduledoc """
  Map data from one thing to another
  """

  alias SmartCity.{Dataset, Organization}
  alias DiscoveryApi.Data.Model

  @doc """
  Map a `SmartCity.Dataset` to a `DiscoveryApi.Data.Model`
  """
  def to_data_model(%Dataset{id: id, technical: tech, business: biz}, %Organization{} = organization) do
    %Model{
      id: id,
      name: tech.dataName,
      title: biz.dataTitle,
      keywords: biz.keywords,
      modifiedDate: biz.modifiedDate,
      fileTypes: get_file_type(tech.sourceFormat),
      description: biz.description,
      systemName: tech.systemName,
      sourceUrl: tech.sourceUrl,
      sourceType: tech.sourceType,
      sourceFormat: tech.sourceFormat,
      private: tech.private,
      accessLevel: ternary(tech.private, "non-public", "public"),
      contactName: biz.contactName,
      contactEmail: biz.contactEmail,
      license:
        ternary(blank?(biz.license) and not tech.private, "http://opendefinition.org/licenses/cc-by/", biz.license),
      rights: biz.rights,
      homepage: biz.homepage,
      spatial: biz.spatial,
      temporal: biz.temporal,
      publishFrequency: biz.publishFrequency,
      conformsToUri: "https://project-open-data.cio.gov/v1.1/schema/",
      describedByUrl: biz.describedByUrl,
      describedByMimeType: biz.describedByMimeType,
      parentDataset: biz.parentDataset,
      issuedDate: biz.issuedDate,
      language: biz.language,
      referenceUrls: biz.referenceUrls,
      categories: biz.categories,
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

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
