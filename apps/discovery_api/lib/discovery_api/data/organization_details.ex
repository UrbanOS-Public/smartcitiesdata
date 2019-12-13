defmodule DiscoveryApi.Data.OrganizationDetails do
  @derive Jason.Encoder
  defstruct [
    :id,
    :orgName,
    :orgTitle,
    :description,
    :logoUrl,
    :homepage
  ]
end
