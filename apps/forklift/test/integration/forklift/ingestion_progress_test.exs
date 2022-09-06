defmodule Forklift.IngestionProgressTest do
  alias Forklift.IngestionProgress
  use ExUnit.Case

  setup_all do
    on_exit(fn ->
      {:ok, _} = Redix.command(:redix, ["flushall"])
    end)
  end

  setup do
    {:ok, _} = Redix.command(:redix, ["flushall"])
    [ingestion_id: Faker.UUID.v4()]
  end

  describe "IngestionTest" do
    test "new_message updates the message count when called", %{ingestion_id: ingestion_id} do
      IngestionProgress.new_message(ingestion_id)
      resulting_count = Redix.command!(:redix, ["GET", ingestion_id <> "_count"])
      assert resulting_count == "1"
    end

    test "new_message returns :in_progress if message count *has not* met existing ingestion target", %{
      ingestion_id: ingestion_id
    } do
      Redix.command!(:redix, ["SET", ingestion_id <> "_target", 2])
      result = IngestionProgress.new_message(ingestion_id)
      assert result == :in_progress
    end

    test "new_message returns :in_progress if message count ingestion target does not exist", %{
      ingestion_id: ingestion_id
    } do
      result = IngestionProgress.new_message(ingestion_id)
      assert result == :in_progress
    end

    test "new_message returns :ingestion_complete if message count *has* met ingestion target", %{
      ingestion_id: ingestion_id
    } do
      Redix.command!(:redix, ["SET", ingestion_id <> "_target", 1])
      result = IngestionProgress.new_message(ingestion_id)
      assert result == :ingestion_complete
    end

    test "new_message resets _count and _target if message count *has* met ingestion target", %{
      ingestion_id: ingestion_id
    } do
      Redix.command!(:redix, ["SET", ingestion_id <> "_target", 1])
      IngestionProgress.new_message(ingestion_id)
      assert Redix.command!(:redix, ["GET", ingestion_id <> "_target"]) == nil
      assert Redix.command!(:redix, ["GET", ingestion_id <> "_count"]) == nil
    end

    test "store_target stores target value in redis", %{ingestion_id: ingestion_id} do
      IngestionProgress.store_target(ingestion_id, 7)
      assert Redix.command!(:redix, ["GET", ingestion_id <> "_target"]) == "7"
    end

    test "store_target returns :in_progress if count doesn't exist", %{ingestion_id: ingestion_id} do
      assert IngestionProgress.store_target(ingestion_id, 7) == :in_progress
    end

    test "store_target returns :in_progress if count is *less than* new target", %{ingestion_id: ingestion_id} do
      Redix.command!(:redix, ["SET", ingestion_id <> "_count", 6])
      assert IngestionProgress.store_target(ingestion_id, 7) == :in_progress
    end

    test "store_target returns :ingestion_complete if count meets new target", %{ingestion_id: ingestion_id} do
      Redix.command!(:redix, ["SET", ingestion_id <> "_count", 3])
      assert IngestionProgress.store_target(ingestion_id, 3) == :ingestion_complete
    end

    test "ingestion count and target are cleared when target is achieved", %{ingestion_id: ingestion_id} do
      Redix.command!(:redix, ["SET", ingestion_id <> "_count", 3])
      IngestionProgress.store_target(ingestion_id, 3)
      assert Redix.command!(:redix, ["GET", ingestion_id <> "_target"]) == nil
      assert Redix.command!(:redix, ["GET", ingestion_id <> "_count"]) == nil
    end
  end
end
