defmodule TransitRealtime.Position do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:latitude, 1, required: true, type: :float)
  field(:longitude, 2, required: true, type: :float)
  field(:bearing, 3, optional: true, type: :float)
  field(:odometer, 4, optional: true, type: :double)
  field(:speed, 5, optional: true, type: :float)
end
