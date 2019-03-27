defmodule TransitRealtime.Alert.Cause do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:UNKNOWN_CAUSE, 1)
  field(:OTHER_CAUSE, 2)
  field(:TECHNICAL_PROBLEM, 3)
  field(:STRIKE, 4)
  field(:DEMONSTRATION, 5)
  field(:ACCIDENT, 6)
  field(:HOLIDAY, 7)
  field(:WEATHER, 8)
  field(:MAINTENANCE, 9)
  field(:CONSTRUCTION, 10)
  field(:POLICE_ACTIVITY, 11)
  field(:MEDICAL_EMERGENCY, 12)
end
