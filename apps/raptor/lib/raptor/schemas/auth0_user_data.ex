defmodule Raptor.Schemas.Auth0UserData do
  @moduledoc """
  This module defines the structure for a user stored in Auth0
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          user_id: String.t(),
          app_metadata: Map.t(),
          blocked: boolean(),
          email_verified: boolean()
        }

  defstruct [
    :user_id,
    :app_metadata,
    :blocked,
    :email_verified
  ]

  use Accessible

  def from_map(%{} = map_data) do
    normalized_data =
      map_data
      |> AtomicMap.convert(safe: false, underscore: false)

    struct(%__MODULE__{}, normalized_data)
  end
end
