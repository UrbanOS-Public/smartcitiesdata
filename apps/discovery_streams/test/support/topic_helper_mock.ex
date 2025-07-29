defmodule DiscoveryStreams.TopicHelperBehaviour do
  @moduledoc false
  # Mox mock behaviour for DiscoveryStreams.TopicHelper

  @callback delete_input_topic(any()) :: :ok | {:error, any()}
end