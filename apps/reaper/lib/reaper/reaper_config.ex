defmodule Reaper.ReaperConfig do
  @moduledoc """
  This module defines the structure for dataset configurations to be processed by Reaper
  """

  @derive Jason.Encoder

  @type t :: %__MODULE__{
          dataset_id: String.t(),
          cadence: String.t() | integer() | nil,
          lastSuccessTime: String.t() | nil,
          sourceFormat: String.t(),
          sourceUrl: String.t(),
          authUrl: String.t(),
          sourceType: String.t(),
          partitioner: map(),
          sourceQueryParams: map(),
          schema: list(),
          protocol: list(),
          sourceHeaders: map(),
          authHeaders: map(),
          allow_duplicates: boolean()
        }

  defstruct [
    :dataset_id,
    :cadence,
    :lastSuccessTime,
    :sourceFormat,
    :sourceUrl,
    :authUrl,
    :sourceType,
    :partitioner,
    :sourceQueryParams,
    :schema,
    :protocol,
    :allow_duplicates,
    sourceHeaders: %{},
    authHeaders: %{}
  ]

  @doc """
  Converts a `SmartCity.Dataset` to a `Reaper.ReaperConfig`
  """
  @spec from_dataset(SmartCity.Dataset.t()) :: {:ok, Reaper.ReaperConfig.t()}
  def from_dataset(%SmartCity.Dataset{} = dataset) do
    struct = %__MODULE__{
      dataset_id: dataset.id,
      cadence: dataset.technical.cadence,
      sourceFormat: dataset.technical.sourceFormat,
      sourceUrl: dataset.technical.sourceUrl,
      authUrl: dataset.technical.authUrl,
      sourceType: dataset.technical.sourceType,
      partitioner: dataset.technical.partitioner,
      sourceQueryParams: dataset.technical.sourceQueryParams,
      sourceHeaders: dataset.technical.sourceHeaders,
      authHeaders: dataset.technical.authHeaders,
      schema: dataset.technical.schema,
      protocol: dataset.technical.protocol,
      allow_duplicates: dataset.technical.allow_duplicates
    }

    {:ok, struct}
  end

  @doc """
  Convert a `Reaper.ReaperConfig` into JSON
  """
  @spec encode(Reaper.ReaperConfig.t()) :: {:ok, String.t()} | {:error, Jason.EncodeError.t() | Exception.t()}
  def encode(%__MODULE__{} = reaper_config) do
    Jason.encode(reaper_config)
  end

  def encode!(%__MODULE__{} = reaper_config) do
    Jason.encode!(reaper_config)
  end
end
