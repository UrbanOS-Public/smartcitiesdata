defmodule Estuary.Datasets.DatasetSchema do
  @moduledoc """
  The schema information that estuary persists and references for a given dataset
  """
  alias SmartCity.Dataset
  defstruct id: nil, system_name: nil, columns: []

  def from_dataset(%Dataset{
        id: id,
        technical: %{schema: schema, sourceType: source_type, systemName: system_name}
      })
      when source_type in ["ingest", "stream"] do
    %__MODULE__{
      id: id,
      system_name: system_name,
      columns: schema
    }
  end

  def from_dataset(_schema_map) do
    :invalid_schema
  end
end
