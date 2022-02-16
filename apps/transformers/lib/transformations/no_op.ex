defmodule Transformers.NoOp do
  @behaviour Transformation

  @impl Transformation
  def transform!(message) do
    message
  end
end
