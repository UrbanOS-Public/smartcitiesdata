defmodule DiscoveryApi.Quantum.Scheduler do
  @moduledoc """
  This modules defines a quantum scheduler which can be wired to run arbitrary functions
  from within config.exs
  """
  use Quantum.Scheduler, otp_app: :discovery_api
end
