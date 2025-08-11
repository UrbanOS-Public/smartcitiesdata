defmodule Reaper.CsvDecoderBehaviour do
  @callback decode({:file, String.t()}, %SmartCity.Ingestion{}) ::
              {:ok, Enumerable.t()} | {:error, any(), any()}
  @callback handle?(String.t()) :: boolean()
end