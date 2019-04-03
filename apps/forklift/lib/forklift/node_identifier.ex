defmodule Forklift.NodeIdentifier do
  @moduledoc false
  @behaviour Exq.NodeIdentifier.Behaviour
  def node_id do
    System.get_env("NODE_ID")
  end
end
