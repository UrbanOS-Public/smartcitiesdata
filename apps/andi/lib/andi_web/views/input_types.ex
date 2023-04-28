defmodule AndiWeb.Views.InputTypes do
  @select "select"
  @enter "enter"

  @input_types %{
    "Data type": @select,
    conditionCompareTo: @select,
    conditionDataType: @select,
    conditionOperation: @select,
    "Source Data Type": @select,
    sourceFormat: @select,
    targetDatasets: @select,
    "Target Data Type": @select,
    type: @select,
    valueType: @select
  }

  def get(field_key) do
    input_type = Map.get(@input_types, field_key)
    if is_nil(input_type), do: @enter, else: input_type
  end
end
