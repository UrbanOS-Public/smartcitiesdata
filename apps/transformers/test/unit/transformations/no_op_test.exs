defmodule Transformers.NoOpTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  describe "The No Op Transform" do
    test "does not alter the message it recieves" do
      original_message = TDG.create_data(%{})

      result = Transformers.NoOp.transform!(original_message)

      assert result == original_message
    end
  end
end
