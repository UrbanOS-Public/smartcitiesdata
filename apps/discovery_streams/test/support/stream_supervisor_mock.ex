defmodule DiscoveryStreams.StreamSupervisorBehaviour do
  @moduledoc false
  # Mox mock behaviour for DiscoveryStreams.Stream.Supervisor
  
  @callback start_child(any()) :: :ok | {:error, any()}
  @callback terminate_child(any()) :: :ok | {:error, any()}
end