defmodule TransitRealtime.VehicleDescriptor do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          license_plate: String.t()
        }
  @derive Jason.Encoder
  defstruct [:id, :label, :license_plate]

  field(:id, 1, optional: true, type: :string)
  field(:label, 2, optional: true, type: :string)
  field(:license_plate, 3, optional: true, type: :string)
end
