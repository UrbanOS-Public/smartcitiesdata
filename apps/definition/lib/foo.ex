defmodule Foo do
  use Definition, schema: Foo.V2
  defstruct [:version, :id, :bar, :baz]

  def on_new(foo, id_generator \\ Application.get_env(:definition, :id_generator, IdGenerator.Impl)) do

    new_baz =
      case foo.baz do
        nil -> nil
        x -> String.upcase(x)
      end

    new_id =
      if Map.has_key?(foo, :id) and not is_nil(foo.id) do
        foo.id
      else
        id_generator.uuid4()
      end

    %{foo | id: new_id, baz: new_baz}
    |> Ok.ok()
  end

  def migrate(%__MODULE__{version: 1} = old) do
    new_id = if Map.has_key?(old, :id), do: old.id, else: "fake_id"

    struct(__MODULE__, %{version: 2, id: new_id, bar: String.to_integer(old.bar)})
    |> Ok.ok()
  end

  defmodule V1 do
    use Definition.Schema

    def s do
      schema(%Foo{
        version: spec(fn v -> v == 1 end),
        bar: spec(is_binary())
      })
    end
  end

  defmodule V2 do
    use Definition.Schema

    def s do
      schema(%Foo{
        version: spec(fn v -> v == 2 end),
        id: required_string(),
        bar: spec(is_integer())
      })
    end
  end
end
