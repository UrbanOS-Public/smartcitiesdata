defmodule TransitRealtime.Position do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          latitude: float,
          longitude: float,
          bearing: float,
          odometer: float,
          speed: float
        }
  @derive Jason.Encoder
  defstruct [:latitude, :longitude, :bearing, :odometer, :speed]

  field(:latitude, 1, required: true, type: :float)
  field(:longitude, 2, required: true, type: :float)
  field(:bearing, 3, optional: true, type: :float)
  field(:odometer, 4, optional: true, type: :double)
  field(:speed, 5, optional: true, type: :float)
end
