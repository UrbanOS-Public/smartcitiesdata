defmodule Dictionary.Type.Map do
  @moduledoc """
  Map type. Normalization of the map normalizes its specified dictionary.

  ## Init options

  * `dictionary` - `Dictionary.t()` impl for the key/value pairs in this map.
  """
  use Definition, schema: Dictionary.Type.Map.V1
  use JsonSerde, alias: "dictionary_map"
  @behaviour Access

  @type t :: %__MODULE__{
          version: integer,
          name: String.t(),
          description: String.t(),
          dictionary: Dictionary.t()
        }

  defstruct version: 1,
            name: nil,
            description: "",
            dictionary: Dictionary.from_list([])

  @impl Definition
  def on_new(%{dictionary: list} = map) when is_list(list) do
    dictionary = Dictionary.from_list(list)

    Map.put(map, :dictionary, dictionary)
    |> Ok.ok()
  end

  def on_new(map) do
    Ok.ok(map)
  end

  @impl Access
  def fetch(%{dictionary: dictionary}, key) do
    Dictionary.Impl.fetch(dictionary, key)
  end

  @impl Access
  def get_and_update(map, key, function) do
    {return, new_dictionary} = Dictionary.Impl.get_and_update(map.dictionary, key, function)
    {return, Map.put(map, :dictionary, new_dictionary)}
  end

  @impl Access
  def pop(map, key) do
    field = Dictionary.get_field(map.dictionary, key)
    new_dict = Dictionary.delete_field(map.dictionary, key)
    {field, Map.put(map, :dictionary, new_dict)}
  end

  defimpl Dictionary.Type.Normalizer, for: __MODULE__ do
    def normalize(_, nil), do: Ok.ok(nil)

    def normalize(%{dictionary: dictionary}, map) do
      Dictionary.normalize(dictionary, map)
    end
  end
end

defmodule Dictionary.Type.Map.V1 do
  @moduledoc false
  use Definition.Schema

  @impl true
  def s do
    schema(%Dictionary.Type.Map{
      version: version(1),
      name: lowercase_string(),
      description: string(),
      dictionary: of_struct(Dictionary.Impl)
    })
  end
end
