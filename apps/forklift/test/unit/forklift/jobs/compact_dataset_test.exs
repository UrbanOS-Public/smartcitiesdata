defmodule CompactDatasetTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    # dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})

    allow(Prestige.execute(any()), return: :ok)
    allow(Prestige.prefetch(any()), return: :ok)

    :ok
  end

  @moduletag capture_log: true
  test "creates a new table from the old one" do
    dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})

    expected_statement = "create table big_data_compact as (select * from big_data)"
    expect(Prestige.execute(expected_statement), return: :ok)

    Forklift.Compactor.compact(dataset)

    assert_called(Prestige.execute(expected_statement), once())
  end

  @moduletag capture_log: true
  test "renames old table to systemName_archive" do
    dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})

    expected_statement = "alter table big_data rename to big_data_archive"

    expect(Prestige.execute(expected_statement),
      return: :ok
    )

    Forklift.Compactor.compact(dataset)

    assert_called(Prestige.execute(expected_statement), once())
  end

  @moduletag capture_log: true
  test "renames compact table to systemName" do
    dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})

    expected_statement = "alter table big_data_compact rename to big_data"

    expect(Prestige.execute(expected_statement),
      return: :ok
    )

    Forklift.Compactor.compact(dataset)

    assert_called(Prestige.execute(expected_statement), once())
  end

  @moduletag capture_log: true
  test "drops old archive table if it exist" do
    dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})

    expected_statement = "drop table big_data_archive"

    expect(Prestige.execute(expected_statement),
      return: :ok
    )

    Forklift.Compactor.compact(dataset)

    assert_called(Prestige.execute(expected_statement), once())
  end
end
