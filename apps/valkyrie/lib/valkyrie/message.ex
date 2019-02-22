defmodule SCOS.Message do
  defstruct payload: nil, metadata: %{}, operational: %{valkyrie: %{}}

  def parse_message(value) when is_binary(value) do
    value
    |> Jason.decode!(keys: :atoms)
    |> make_struct()
  end

  def encode_message(%__MODULE__{} = message) do
    message
    |> Map.from_struct()
    |> Jason.encode!()
  end

  def put_operational(%__MODULE__{operational: operational} = message, app, key, value) do
    operational = Map.put_new(operational, app, %{})

    new_operational = put_in(operational, [app, key], value)

    %{message | operational: new_operational}
  end

  # Private functions
  defp make_struct(value_map) do
    struct!(__MODULE__, value_map)
  end
end
