defmodule Transformers.NoOp do
  @behaviour Transformation

  @impl Transformation
  def transform(message, _parameters) do
    message
  end
end
