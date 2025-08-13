defmodule MetricsServiceBehaviour do
  @moduledoc """
  Behaviour for the MetricsService module to enable mocking
  """
  
  @callback record_csv_download_count_metrics(any(), any()) :: any()
  @callback record_query_metrics(any(), any(), any()) :: any()
  @callback record_api_hit(any(), any()) :: any()
end