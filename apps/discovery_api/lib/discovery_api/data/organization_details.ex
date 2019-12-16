defmodule DiscoveryApi.Data.OrganizationDetails do
  @moduledoc """
  This struct represents the details about an organization that the Discovery API cares about.
  """

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
