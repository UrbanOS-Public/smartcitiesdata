defmodule Forklift.NodeIdentifier do
  @behaviour Exq.NodeIdentifier.Behaviour

  def node_id do
    System.get_env("NODE_ID")
  end
end
