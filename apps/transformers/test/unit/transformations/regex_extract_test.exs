defmodule Transformers.RegexExtractTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  # describe "The regex extract transform" do
  #    ? validate that it has all the parameters it needs?
  #      ^ not needed. On all instances of a Transformation, if "transform"
  #       fails, we'll handle that in whoever is consuming this library (alchemist)
  #   # We don't want a struct for each transformations parameter set right?
  #   test "returns an error if the specified source field does not exist" do
  #     params = %{
  #       sourceField: "source_field",
  #       targetField: "target_field",
  #       regex: "^\((\d{3})\)"
  #     }

  #     message = TDG.create_data(%{})

  #     {:error, reason} = Transformers.RegexExtract.transform(message, params)

  #     assert reason == :invalid_message
  #   end
  # end
end
