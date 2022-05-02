defmodule DiscoveryApi.Data.Mapper do
  @moduledoc """
  Map data from one thing to another
  """

  alias SmartCity.Dataset
  alias DiscoveryApi.Schemas.Organizations.Organization
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Data.OrganizationDetails
  use Properties, otp_app: :discovery_api

  getter(:raptor_url, generic: true)

  @doc """
  Map a `SmartCity.Dataset` to a `DiscoveryApi.Data.Model`
  """
  def to_data_model(%Dataset{id: id, technical: tech, business: biz}, %Organization{} = organization) do
    access_groups = retrieveAccessGroups(id)

    %Model{
      id: id,
      name: tech.dataName,
      title: biz.dataTitle,
      keywords: biz.keywords,
      modifiedDate: biz.modifiedDate,
      fileTypes: get_file_type(tech.sourceFormat),
      description: biz.description,
      schema: tech.schema,
      systemName: tech.systemName,
      sourceUrl: tech.sourceUrl,
      sourceType: tech.sourceType,
      sourceFormat: tech.sourceFormat,
      private: tech.private,
      accessLevel: ternary(tech.private, "non-public", "public"),
      contactName: biz.contactName,
      contactEmail: biz.contactEmail,
      license: ternary(blank?(biz.license) and not tech.private, "http://opendefinition.org/licenses/cc-by/", biz.license),
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
      organization: organization.title,
      organizationDetails: %OrganizationDetails{
        id: organization.id,
        orgName: organization.name,
        orgTitle: organization.title,
        description: organization.description,
        logoUrl: organization.logo_url,
        homepage: organization.homepage
      },
      accessGroups: access_groups
    }
  end

  def add_access_group(dataset_model, access_group) do
    %Model{dataset_model | accessGroups: dataset_model.accessGroups ++ [access_group]}
  end

  def remove_access_group(dataset_model, access_group) do
    %Model{dataset_model | accessGroups: List.delete(dataset_model.accessGroups, access_group)}
  end

  defp retrieveAccessGroups(dataset_id) do
    RaptorService.list_access_groups_by_dataset(raptor_url(), dataset_id)
  end

  defp get_file_type("application/gtfs+protobuf"), do: ["JSON"]
  defp get_file_type(source_format), do: source_format |> MIME.extensions() |> hd() |> String.upcase() |> List.wrap()

  defp ternary(condition, success, _failure) when condition, do: success
  defp ternary(_condition, _success, failure), do: failure

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
