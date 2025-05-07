defmodule Andi.Services.IngestionStoreTest do
  use ExUnit.Case

  import Mock

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.IngestionStore

  describe "update/1" do
    test "gets ingestion event from Brook" do
      %{id: id} = ingestion = TDG.create_ingestion(%{})

      with_mock(Brook.ViewState, merge: fn :ingestion, id, ingestion -> :ok end) do
        assert :ok == IngestionStore.update(ingestion)
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      %{id: id} = ingestion = TDG.create_ingestion(%{})

      with_mock(Brook.ViewState, merge: fn :ingestion, id, ingestion -> expected_error end) do
        assert expected_error == IngestionStore.update(ingestion)
      end
    end
  end

  describe "get/1" do
    test "gets ingestion event from Brook" do
      id = "ingestion-id"
      expected_ingestion = TDG.create_ingestion(%{id: id})
      instance_name = Andi.instance_name()

      with_mock(Brook, get: fn instance_name, :ingestion, id -> expected_ingestion end) do
        assert expected_ingestion == IngestionStore.get(expected_ingestion.id)
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()

      with_mock(Brook, get: fn instance_name, :ingestion, "some-id" -> expected_error end) do
        assert expected_error == IngestionStore.get("some-id")
      end
    end
  end

  describe "get_all/0" do
    test "retrieves all events from Brook" do
      ingestion1 = TDG.create_ingestion(%{})
      ingestion2 = TDG.create_ingestion(%{})
      expected_ingestions = {:ok, [ingestion1, ingestion2]}
      instance_name = Andi.instance_name()

      with_mock(Brook, get_all_values!: fn instance_name, :ingestion -> expected_ingestions end) do
        assert expected_ingestions == IngestionStore.get_all()
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}
      instance_name = Andi.instance_name()

      with_mock(Brook, get_all_values!: fn instance_name, :ingestion -> expected_error end) do
        assert expected_error == IngestionStore.get_all()
      end
    end
  end

  describe "get_all!/0" do
    test "raises the error returned by brook" do
      expected_error = "bad things"
      instance_name = Andi.instance_name()

      with_mock(Brook, get_all_values!: fn instance_name, :ingestion -> expected_error end) do
        assert expected_error == IngestionStore.get_all!()
      end
    end
  end

  describe "delete/1" do
    test "deletes ingestion event from Brook" do
      with_mock(Brook.ViewState, delete: fn :ingestion, "some-id" -> :ok end) do
        assert :ok == IngestionStore.delete("some-id")
      end
    end

    test "returns an error when brook returns an error" do
      expected_error = {:error, "bad things"}

      with_mock(Brook.ViewState, delete: fn :ingestion, "some-id" -> expected_error end) do
        assert expected_error == IngestionStore.delete("some-id")
      end
    end
  end
end
