defmodule Dictionary.Type.List do
  @moduledoc """
  List type. Normalization of the list normalizes all of its elements.

  ## Init options

  * `item_type` - `Dictionary.Type.*` type for list elements.
  """
  use Definition, schema: Dictionary.Type.List.V1
  use JsonSerde, alias: "dictionary_list"
  @behaviour Access

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t(),
          item_type: module
        }

  defstruct version: 1,
            name: nil,
            description: "",
            item_type: nil

  @impl Access
  def fetch(%{item_type: %module{} = item_type}, key) do
    module.fetch(item_type, key)
  end

  @impl Access
  def get_and_update(%{item_type: %module{} = item_type} = list, key, function) do
    {get, update} = module.get_and_update(item_type, key, function)
    {get, %{list | item_type: update}}
  end

  @impl Access
  def pop(%{item_type: %module{} = item_type} = list, key) do
    {value, update} = module.pop(item_type, key)
    {value, %{list | item_type: update}}
  end

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    alias Dictionary.Type.Normalizer

    def normalize(_, nil), do: Ok.ok(nil)

    def normalize(%{item_type: item_type}, list) do
      Ok.transform(list, &Normalizer.normalize(item_type, &1))
      |> Ok.map_if_error(fn reason -> {:invalid_list, reason} end)
    end
  end
end

defmodule Dictionary.Type.List.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.List{
      version: version(1),
      name: lowercase_string(),
      description: string(),
      item_type: spec(is_map())
    })
  end
end
