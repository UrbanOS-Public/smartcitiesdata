defmodule Andi.Services.IngestionStoreTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      ingestion1 = TDG.create_ingestion(%{})
      ingestion2 = TDG.create_ingestion(%{})
      expected_ingestions = {:ok, [ingestion1, ingestion2]}
      allow(IngestionStore.get_all(), return: expected_ingestions)
      assert expected_ingestions == IngestionStore.get_all()
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(IngestionStore.get_all(), return: expected_error)
      assert expected_error == IngestionStore.get_all()
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      expected_error = "bad things"
      allow(IngestionStore.get_all!(), return: expected_error)
      assert expected_error == IngestionStore.get_all!()
    end
  end
end
