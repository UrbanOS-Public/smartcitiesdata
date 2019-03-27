defmodule Reaper.ReaperConfig do
  @moduledoc false

  @derive Jason.Encoder

  defstruct [
    :dataset_id,
    :cadence,
    :lastSuccessTime,
    :sourceFormat,
    :sourceUrl,
    :sourceType,
    :partitioner,
    :queryParams,
    :schema
  ]

  def from_dataset(%SmartCity.Dataset{} = dataset) do
    struct = %__MODULE__{
      dataset_id: dataset.id,
      cadence: dataset.technical.cadence,
      sourceFormat: dataset.technical.sourceFormat,
      sourceUrl: dataset.technical.sourceUrl,
      sourceType: dataset.technical.sourceType,
      partitioner: dataset.technical.partitioner,
      schema: dataset.technical.schema,
      queryParams: dataset.technical.queryParams
    }

    {:ok, struct}
  end

  def encode(%__MODULE__{} = reaper_config) do
    Jason.encode(reaper_config)
  end

  def encode!(%__MODULE__{} = reaper_config) do
    Jason.encode!(reaper_config)
  end
end
