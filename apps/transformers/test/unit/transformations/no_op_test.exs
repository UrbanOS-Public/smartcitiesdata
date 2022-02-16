defmodule Transformers.NoOpTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG

  describe "The No Op Transform" do
    test "does not alter the message it recieves" do
      %{payload: payload} = TDG.create_data(%{})

      result = Transformers.NoOp.transform(payload, {})

      assert result == payload
    end
  end
end
