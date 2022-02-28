defmodule Transformers.DateTime do
  @behaviour Transformation

  @impl Transformation

  def transform(payload, parameters) do
    {:ok, %{"date2" => "some date"}}
  end
end
