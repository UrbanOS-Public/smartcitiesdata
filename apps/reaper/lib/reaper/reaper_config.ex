defmodule Reaper.ReaperConfig do
  @moduledoc false

  @derive Jason.Encoder
  defstruct [:dataset_id, :cadence, :lastSuccessTime, :sourceFormat, :sourceUrl, :queryParams]

  def from_registry_message(%SCOS.RegistryMessage{} = registry_message) do
    struct = %__MODULE__{
      dataset_id: registry_message.id,
      cadence: registry_message.technical.cadence,
      sourceFormat: registry_message.technical.sourceFormat,
      sourceUrl: registry_message.technical.sourceUrl,
      queryParams: registry_message.technical.queryParams
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
