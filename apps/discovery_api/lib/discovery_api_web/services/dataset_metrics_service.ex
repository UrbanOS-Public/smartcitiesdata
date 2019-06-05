defmodule DiscoveryApiWeb.DatasetMetricsService do
  @moduledoc false
  def record_api_hit(request_type, dataset_id) do
    Redix.command!(:redix, ["INCR", "smart_registry:#{request_type}:count:#{dataset_id}"])
  end
end
