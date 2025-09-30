defmodule TransitRealtime.VehicleDescriptor do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:id, 1, optional: true, type: :string)
  field(:label, 2, optional: true, type: :string)
  field(:license_plate, 3, optional: true, type: :string)
end
