defmodule TransitRealtime.VehiclePosition do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

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
