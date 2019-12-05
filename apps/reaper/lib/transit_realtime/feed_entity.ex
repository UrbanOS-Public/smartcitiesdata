defmodule TransitRealtime.FeedEntity do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          id: String.t(),
          is_deleted: boolean,
          trip_update: TransitRealtime.TripUpdate.t(),
          vehicle: TransitRealtime.VehiclePosition.t(),
          alert: TransitRealtime.Alert.t()
        }
  @derive Jason.Encoder
  defstruct [:id, :is_deleted, :trip_update, :vehicle, :alert]

  field(:id, 1, required: true, type: :string)
  field(:is_deleted, 2, optional: true, type: :bool, default: false)
  field(:trip_update, 3, optional: true, type: TransitRealtime.TripUpdate)
  field(:vehicle, 4, optional: true, type: TransitRealtime.VehiclePosition)
  field(:alert, 5, optional: true, type: TransitRealtime.Alert)
end
