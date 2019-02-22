defmodule Operational do
  @moduledoc false
  use TypedStruct

  @typedoc "Operational configuration for a dataset"
  @derive Jason.Encoder
  typedstruct do
    field :cadence, non_neg_integer(), enforce: true
    field :sourceUrl, String.t(), enforce: true
    field :sourceFormat, String.t(), enforce: true
    field :queryParams, Map.t(), enforce: true
    field :headers, Map.t()
    field :organization, String.t()
    field :status, String.t()
    field :transformations, List.t()
    field :version, String.t()
  end
end

defmodule Dataset do
  @moduledoc false
  use TypedStruct

  @typedoc "Dataset metadata and configuration"
  @derive Jason.Encoder
  typedstruct do
    field :id, String.t(), enforce: true
    field :business, term(), enforce: true
    field :operational, Operational.t(), enforce: true
  end

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
      |> Map.update(:operational, %{}, fn op -> struct!(Operational, op) end)

    {:ok, dataset_struct}
  rescue
    error ->
      {:error, "Unable to parse dataset into dataset object for dataset: #{inspect(dataset)} - #{inspect(error)}"}
  end
end
