defmodule Forklift.NodeIdentifier do
  @moduledoc """
  This behavior allows us to override the node id for use in environments like Kubernetes where nodes go up and down and so we can't just default to the machine id.
  """
  @behaviour Exq.NodeIdentifier.Behaviour
  def node_id do
    System.get_env("NODE_ID")
  end
end
