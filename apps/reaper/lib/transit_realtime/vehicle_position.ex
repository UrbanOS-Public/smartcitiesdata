defmodule TransitRealtime.VehiclePosition do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          trip: TransitRealtime.TripDescriptor.t(),
          vehicle: TransitRealtime.VehicleDescriptor.t(),
          position: TransitRealtime.Position.t(),
          current_stop_sequence: non_neg_integer,
          stop_id: String.t(),
          current_status: integer,
          timestamp: non_neg_integer,
          congestion_level: integer,
          occupancy_status: integer
        }
  @derive Jason.Encoder
  defstruct [
    :trip,
    :vehicle,
    :position,
    :current_stop_sequence,
    :stop_id,
    :current_status,
    :timestamp,
    :congestion_level,
    :occupancy_status
  ]

  field(:trip, 1, optional: true, type: TransitRealtime.TripDescriptor)
  field(:vehicle, 8, optional: true, type: TransitRealtime.VehicleDescriptor)
  field(:position, 2, optional: true, type: TransitRealtime.Position)
  field(:current_stop_sequence, 3, optional: true, type: :uint32)
  field(:stop_id, 7, optional: true, type: :string)

  field(
    :current_status,
    4,
    optional: true,
    type: TransitRealtime.VehiclePosition.VehicleStopStatus,
    default: :IN_TRANSIT_TO,
    enum: true
  )

  field(:timestamp, 5, optional: true, type: :uint64)

  field(
    :congestion_level,
    6,
    optional: true,
    type: TransitRealtime.VehiclePosition.CongestionLevel,
    enum: true
  )

  field(
    :occupancy_status,
    9,
    optional: true,
    type: TransitRealtime.VehiclePosition.OccupancyStatus,
    enum: true
  )
end
