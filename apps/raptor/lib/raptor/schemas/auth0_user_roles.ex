defmodule Raptor.Schemas.Auth0UserRole do
  @moduledoc """
  This module defines the structure for a user stored in Auth0
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          id: String.t(),
          name: Map.t(),
          description: boolean()
        }

  defstruct [
    :id,
    :name,
    :description
  ]

  use Accessible

  def from_map(%{} = map_data) do
    normalized_data =
      map_data
      |> AtomicMap.convert(safe: false, underscore: false)

    struct(%__MODULE__{}, normalized_data)
  end
end
