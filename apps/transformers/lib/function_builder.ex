defmodule Transformers.FunctionBuilder do
  def build(:regex_extract, parameters) do
    fn payload -> Transformers.RegexExtract.transform(payload, parameters) end
  end
end
