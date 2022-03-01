defmodule Transformers.FieldFetcherTest do
  use ExUnit.Case
  alias Transformations.FieldFetcher

  test "fetch parameter returns the value inside the provided params" do
    params = %{
      example: "123"
    }

    result = FieldFetcher.fetch_parameter(params, :example)
    assert result == {:ok, "123"}
  end

  test "fetch parameter returns an error if the key is missing" do
    params = %{
      example: "123"
    }

    result = FieldFetcher.fetch_parameter(params, :missing)
    assert result == {:error, "Missing transformation parameter: missing"}
  end

  test "fetch value returns the value inside the provided payload" do
    payload = %{
      example: "123"
    }

    result = FieldFetcher.fetch_value(payload, :example)
    assert result == {:ok, "123"}
  end

  test "fetch value returns an error if the key is missing" do
    payload = %{
      example: "123"
    }

    result = FieldFetcher.fetch_value(payload, :missing)
    assert result == {:error, "Missing field in payload: missing"}
  end
end
