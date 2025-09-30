defmodule TransitRealtime.EntitySelector do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:agency_id, 1, optional: true, type: :string)
  field(:route_id, 2, optional: true, type: :string)
  field(:route_type, 3, optional: true, type: :int32)
  field(:trip, 4, optional: true, type: TransitRealtime.TripDescriptor)
  field(:stop_id, 5, optional: true, type: :string)
end
