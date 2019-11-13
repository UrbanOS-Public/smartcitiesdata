defmodule TransitRealtime.Alert do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          active_period: [TransitRealtime.TimeRange.t()],
          informed_entity: [TransitRealtime.EntitySelector.t()],
          cause: integer,
          effect: integer,
          url: TransitRealtime.TranslatedString.t(),
          header_text: TransitRealtime.TranslatedString.t(),
          description_text: TransitRealtime.TranslatedString.t()
        }
  @derive Jason.Encoder
  defstruct [
    :active_period,
    :informed_entity,
    :cause,
    :effect,
    :url,
    :header_text,
    :description_text
  ]

  field(:active_period, 1, repeated: true, type: TransitRealtime.TimeRange)
  field(:informed_entity, 5, repeated: true, type: TransitRealtime.EntitySelector)

  field(
    :cause,
    6,
    optional: true,
    type: TransitRealtime.Alert.Cause,
    default: :UNKNOWN_CAUSE,
    enum: true
  )

  field(
    :effect,
    7,
    optional: true,
    type: TransitRealtime.Alert.Effect,
    default: :UNKNOWN_EFFECT,
    enum: true
  )

  field(:url, 8, optional: true, type: TransitRealtime.TranslatedString)
  field(:header_text, 10, optional: true, type: TransitRealtime.TranslatedString)
  field(:description_text, 11, optional: true, type: TransitRealtime.TranslatedString)
end
