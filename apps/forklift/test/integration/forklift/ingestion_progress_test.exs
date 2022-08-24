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

  # todo: new compaction kickoff integration test:
  # - data_extract_end stores message target, assert from redis
  # - compacts when target achieved, assert compaction called
  # - doesn't compact when target not achieved, assert compaction not called

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

    # @tag :skip
    # test "store_target stores target value in redis", %{ingestion_id: ingestion_id} do
    # end

    # @tag :skip
    # test "store_target" returns :in_progress if count doesn't exist", %{ingestion_id: ingestion_id} do
    # end

    # @tag :skip
    # test "store_target" returns :in_progress if count is *less than* new target", %{ingestion_id: ingestion_id} do
    # end

    # @tag :skip
    # test "store_target" returns :ingestion_complete if count meets new target", %{ingestion_id: ingestion_id} do
    # end

    # @tag :skip
    # test "ingestion count and target are cleared when target is achieved", %{ingestion_id: ingestion_id} do
    # end
  end
end
