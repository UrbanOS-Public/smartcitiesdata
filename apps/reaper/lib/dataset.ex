defmodule Dataset do
  @moduledoc false
  @enforce_keys [:id, :business, :operational]
  defstruct [:id, :business, :operational]

  require Protocol
  Protocol.derive(Jason.Encoder, __MODULE__)

  def new(%{"id" => _} = dataset) do
    dataset
    |> Map.new(fn {key, val} -> {String.to_atom(key), val} end)
    |> new()
  end

  def new(dataset) do
    dataset_struct =
      Dataset
      |> struct!(dataset)
      |> Map.update(:id, "invalid", fn id -> to_string(id) end)

    {:ok, dataset_struct}
  rescue
    _ ->
      {:error, "Unable to parse dataset into dataset object for dataset: #{inspect(dataset)}"}
  end
end
