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

  def fields_for("multiplication") do
    Transformers.Multiplication.fields()
  end

  def fields_for("division") do
    Transformers.Division.fields()
  end

  def fields_for("regex_extract") do
    Transformers.RegexExtract.fields()
  end

  def fields_for("regex_replace") do
    Transformers.RegexReplace.fields()
  end

  def fields_for("datetime") do
    Transformers.DateTime.fields()
  end

  def fields_for("conversion") do
    Transformers.TypeConversion.fields()
  end

  def fields_for("concatenation") do
    Transformers.Concatenation.fields()
  end

  def fields_for(_unsupported) do
    []
  end
end
