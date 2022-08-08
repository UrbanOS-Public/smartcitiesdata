defmodule Transformers.TransformationFields do
  alias Transformers

  def fields_for("remove") do
    Transformers.Remove.fields()
  end

  def fields_for(_unsupported) do
    []
  end
end
