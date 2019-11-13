defmodule TransitRealtime.TranslatedString do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          translation: [TransitRealtime.TranslatedString.Translation.t()]
        }
  @derive Jason.Encoder
  defstruct [:translation]

  field(:translation, 1, repeated: true, type: TransitRealtime.TranslatedString.Translation)
end
