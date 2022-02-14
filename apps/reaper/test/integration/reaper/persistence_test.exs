defmodule PersistenceTest do
  use ExUnit.Case
  alias Reaper.Persistence
  alias Reaper.ReaperConfig
  use Divo

  @dataset_id "12345-3323"
  @redix Reaper.Application.redis_client()

  setup do
    Redix.command!(@redix, ["FLUSHALL"])
    :ok
  end

  test "get should return nil when reaper config does not exist" do
    assert nil == Persistence.get("123456")
  end



  test "get all returns empty list if no keys exist" do
    assert [] == Persistence.get_all()
  end
end
