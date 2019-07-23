defmodule CompactDatasetTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  describe "compact_dataset/1" do
    setup do
      dataset = TDG.create_dataset(%{id: "1", technical: %{systemName: "big_data"}})
      allow(Prestige.prefetch(any()), return: :ok)

      [
        dataset: dataset
      ]
    end

    test "creates a new table from the old one", %{dataset: dataset} do
      expected_statement = "create table big_data_compact as (select * from big_data)"
      expect(Prestige.execute(expected_statement), return: :ok)
      allow(Prestige.execute(any()), return: :ok)

      Forklift.Compactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement), once())
    end

    test "renames old table to systemName_archive", %{dataset: dataset} do
      expected_statement = "alter table big_data rename to big_data_archive"

      expect(Prestige.execute(expected_statement), return: :ok)
      allow(Prestige.execute(any()), return: :ok)

      Forklift.Compactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement), once())
    end

    test "renames compact table to systemName", %{dataset: dataset} do
      expected_statement = "alter table big_data_compact rename to big_data"

      expect(Prestige.execute(expected_statement), return: :ok)
      allow(Prestige.execute(any()), return: :ok)

      Forklift.Compactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement), once())
    end

    test "drops old archive table if it exist", %{dataset: dataset} do
      expected_statement = "drop table big_data_archive"

      expect(Prestige.execute(expected_statement), return: :ok)
      allow(Prestige.execute(any()), return: :ok)

      Forklift.Compactor.compact_dataset(dataset)

      assert_called(Prestige.execute(expected_statement), once())
    end
  end

  describe "compact_datasets/0" do
    test "only processes ingest type datasets" do
      datasets = [
        TDG.create_dataset(%{id: "1", technical: %{systemName: "remote", sourceType: "remote"}}),
        TDG.create_dataset(%{id: "2", technical: %{systemName: "ingest", sourceType: "ingest"}}),
        TDG.create_dataset(%{id: "3", technical: %{systemName: "host", sourceType: "host"}})
      ]

      allow(SmartCity.Dataset.get_all!(), return: datasets)
      allow(Prestige.execute(any()), return: :ok)
      allow(Prestige.prefetch(any()), return: :ok)

      Forklift.Compactor.compact_datasets()

      assert_called(
        Prestige.execute("create table ingest_compact as (select * from ingest)"),
        once()
      )

      refute_called(Prestige.execute("create table remote_compact as (select * from remote)"))
      refute_called(Prestige.execute("create table host_compact as (select * from host)"))
    end
  end
end
