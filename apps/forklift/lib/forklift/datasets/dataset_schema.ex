defmodule Forklift.Datasets.DatasetSchema do
  @moduledoc """
  The schema information that forklift persists and references for a given dataset
  """
  defstruct id: nil, system_name: nil, columns: []
end
