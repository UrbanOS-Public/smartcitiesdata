defmodule Andi.Services.IngestionStoreTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore

  describe "update/1" do
    test "gets ingestion event from Brook" do
      ingestion = TDG.create_ingestion(%{id: "ingestion-id"})
      allow(Brook.ViewState.merge(:ingestion, ingestion.id, ingestion), return: :ok)
      assert :ok == IngestionStore.update(ingestion)
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      ingestion = TDG.create_ingestion(%{id: "ingestion-id"})
      allow(Brook.ViewState.merge(:ingestion, ingestion.id, ingestion), return: expected_error)
      assert expected_error == IngestionStore.update(ingestion)
    end
  end

  describe "get/1" do
    test "gets ingestion event from Brook" do
      expected_ingestion = TDG.create_ingestion(%{id: "ingestion-id"})
      allow(Brook.get(Andi.instance_name(), :ingestion, expected_ingestion.id), return: expected_ingestion)
      assert expected_ingestion == IngestionStore.get(expected_ingestion.id)
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.get(Andi.instance_name(), :ingestion, "some-id"), return: expected_error)
      assert expected_error == IngestionStore.get("some-id")
    end
  end

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      ingestion1 = TDG.create_ingestion(%{})
      ingestion2 = TDG.create_ingestion(%{})
      expected_ingestions = {:ok, [ingestion1, ingestion2]}
      allow(Brook.get_all_values(Andi.instance_name(), :ingestion), return: expected_ingestions)
      assert expected_ingestions == IngestionStore.get_all()
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.get_all_values(Andi.instance_name(), :ingestion), return: expected_error)
      assert expected_error == IngestionStore.get_all()
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      expected_error = "bad things"
      allow(Brook.get_all_values!(Andi.instance_name(), :ingestion), return: expected_error)
      assert expected_error == IngestionStore.get_all!()
    end
  end

  describe "delete/1" do
    test "deletes ingestion event from Brook" do
      allow(Brook.ViewState.delete(:ingestion, "some-id"), return: :ok)
      assert :ok == IngestionStore.delete("some-id")
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      allow(Brook.ViewState.delete(:ingestion, "some-id"), return: expected_error)
      assert expected_error == IngestionStore.delete("some-id")
    end
  end
end
