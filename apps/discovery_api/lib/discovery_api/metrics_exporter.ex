defmodule DiscoveryApi.MetricsExporter do
  @moduledoc """
    A module for exporting beam metrics to prometheus
  """
  use Prometheus.PlugExporter
end
