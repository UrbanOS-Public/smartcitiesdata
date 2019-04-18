defmodule Flair.Quality do
  @moduledoc false

  alias SmartCity.Dataset

  def get_required_fields(dataset_id) do
    Dataset.get!(dataset_id).technical.schema
    |> Enum.filter(&(Map.get(&1, :required, nil) == true))
    |> Enum.map(&Map.get(&1, :name))

    # Get schema from registry topic
  end

  def get_data_from_redis() do
    # not sure about this one yet
  end

  def calculate_nulls do
    # return count of null fields
  end
end
