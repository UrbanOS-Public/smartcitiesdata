defmodule Forklift.Tables.TableCreatorTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog

  alias Forklift.Tables.TableCreator
  alias Forklift.Tables.StatementBuilder

  describe "successful table creation" do
    setup do
      allow(Prestige.execute(any()), return: :ok)
      allow(Prestige.prefetch(any()), return: [[true]])

      :ok
    end

    test "creates table with constructed create table statement" do
      dataset = FixtureHelper.dataset(id: "ds1")

      TableCreator.create_table(dataset)

      {:ok, expected_statement} =
        StatementBuilder.build_table_create_statement(dataset.technical.systemName, dataset.technical.schema)

      assert_called(Prestige.execute(expected_statement), once())
      assert_called(Prestige.prefetch(any()), once())
    end

    test "does not create table when statement cannot be constructed" do
      dataset = FixtureHelper.dataset(id: "ds1", technical: %{schema: [%{type: "blob", name: "unmappable"}]})

      TableCreator.create_table(dataset)

      refute_called(Prestige.execute(any()))
      refute_called(Prestige.prefetch(any()))
    end

    test "logs success" do
      dataset = FixtureHelper.dataset(id: "ds1")

      fun = fn ->
        TableCreator.create_table(dataset)
      end

      assert capture_log(fun) =~ "Created table for ds1"
    end
  end

  describe "unable to build the create statement" do
    setup do
      dataset = FixtureHelper.dataset(id: "ds1", technical: %{schema: [%{type: "blob", name: "unmappable"}]})

      [dataset: dataset]
    end

    test "does not execute a query", %{dataset: dataset} do
      allow Prestige.execute(any()), return: :ok
      allow Prestige.prefetch(any()), return: [[0]]

      TableCreator.create_table(dataset)

      refute_called Prestige.execute(any())
      refute_called Prestige.prefetch(any())
    end

    test "logs error" do
      allow Prestige.execute(any()), return: :ok
      allow Prestige.prefetch(any()), return: [[0]]

      dataset = FixtureHelper.dataset(id: "ds1")

      fun = fn ->
        TableCreator.create_table(dataset)
      end

      assert capture_log(fun) =~ "Error processing dataset ds1"
    end
  end

  describe "failed table creation" do
    setup do
      allow(Prestige.execute(any()), return: :ok)
      allow(Prestige.prefetch(any()), return: [[0]])

      :ok
    end

    test "returns error when query fails to execute" do
      dataset = FixtureHelper.dataset(id: "ds1")

      assert {:error, _} = TableCreator.create_table(dataset)
    end

    test "logs error" do
      dataset = FixtureHelper.dataset(id: "ds1")

      fun = fn ->
        TableCreator.create_table(dataset)
      end

      assert capture_log(fun) =~ "Error processing dataset ds1"
    end
  end
end
