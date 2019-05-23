defmodule Reaper.ReaperConfig do
  @moduledoc """
  This module defines the structure for dataset configurations to be processed by Reaper
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          dataset_id: integer(),
          cadence: integer(),
          lastSuccessTime: String.t(),
          sourceFormat: String.t(),
          sourceUrl: String.t(),
          sourceType: String.t(),
          partitioner: String.t(),
          queryParams: list(),
          schema: list()
        }

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

  @doc """
  Converts a `SmartCity.Dataset` to a `Reaper.ReaperConfig`
  """
  @spec from_dataset(%SmartCity.Dataset{}) :: {:ok, Reaper.ReaperConfig.t()}
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

  @doc """
  Convert a `Reaper.ReaperConfig` into JSON
  """
  @spec encode(Reaper.ReaperConfig.t()) :: String.t()
  def encode(%__MODULE__{} = reaper_config) do
    Jason.encode(reaper_config)
  end

  def encode!(%__MODULE__{} = reaper_config) do
    Jason.encode!(reaper_config)
  end
end
