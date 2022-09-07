defmodule Transformers.TransformationFields do
  alias Transformers

  def fields_for("remove") do
    Transformers.Remove.fields()
  end

  def fields_for("arithmetic_add") do
    Transformers.ArithmeticAdd.fields()
  end

  def fields_for("arithmetic_subtract") do
    Transformers.ArithmeticSubtract.fields()
  end

  def fields_for(_unsupported) do
    []
  end
end
