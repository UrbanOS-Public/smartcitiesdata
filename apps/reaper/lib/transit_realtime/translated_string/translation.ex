defmodule TransitRealtime.TranslatedString.Translation do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          text: String.t(),
          language: String.t()
        }
  @derive Jason.Encoder
  defstruct [:text, :language]

  field(:text, 1, required: true, type: :string)
  field(:language, 2, optional: true, type: :string)
end
