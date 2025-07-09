defmodule Pipeline.Writer.TableWriter.Helper.PrestigeHelperTest do
  use ExUnit.Case
  import Mox

  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  @expected_table_data %{
    "column_1" => "some column_1 data",
    "column_2" => "some column_2 data"
  }

  setup :verify_on_exit!

  setup do
    Mox.stub_with(PrestigeMock, Prestige)
    :ok
  end

  @tag capture_log: true
  test "should return the data by executing the when the query statement is passed" do
    expect(PrestigeMock, :new_session, fn _ -> :connection end)
    expect(PrestigeMock, :execute, fn :connection, _ -> @expected_table_data end)
    assert @expected_table_data == PrestigeHelper.execute_query("whatever")
  end

  @tag capture_log: true
  test "should return error when error occurs while executing the query" do
    expected_error = {:error, "some error"}
    expect(PrestigeMock, :new_session, fn _ -> :connection end)
    expect(PrestigeMock, :execute, fn :connection, _ -> expected_error end)
    assert expected_error == PrestigeHelper.execute_query("whatever")
  end

  @tag capture_log: true
  test "should attempt to execute query asynchronously" do
    expect(PrestigeMock, :new_session, fn _ -> :connection end)
    expect(PrestigeMock, :execute, fn :connection, _ -> @expected_table_data end)

    actual_table_data =
      PrestigeHelper.execute_async_query("whatever")
      |> Task.await()

    assert @expected_table_data == actual_table_data
  end

  @tag capture_log: true
  test "should create the session and return new session" do
    expected_session = %Prestige.Session{
      catalog: "some_catalog",
      prepared_statements: [],
      receive_timeout: nil,
      schema: "some_schema",
      transaction_id: nil,
      url: "some_url",
      user: "some_user"
    }

    expect(PrestigeMock, :new_session, fn _ -> expected_session end)
    assert expected_session == PrestigeHelper.create_session()
  end

  describe "count!/1" do
    test "throws an exception if an error occurs" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:error, "some error"} end)

      assert_raise RuntimeError, fn ->
        PrestigeHelper.count!("some_table")
      end
    end

    test "returns the count" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:ok, %{rows: [[10]]}} end)

      assert PrestigeHelper.count!("some_table") == 10
    end
  end

  describe "count/1" do
    test "returns an error tuple if an error occurs" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:error, "some error"} end)

      assert PrestigeHelper.count("some_table") == {:error, "some error"}
    end

    test "returns the count in an ok tuple" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:ok, %{rows: [[10]]}} end)

      assert PrestigeHelper.count("some_table") == {:ok, 10}
    end
  end

  describe "count_query!/1" do
    test "throws an exception if an error occurs" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:error, "some error"} end)

      assert_raise RuntimeError, fn ->
        PrestigeHelper.count!("select count(1) from some_table")
      end
    end

    test "returns the count" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:ok, %{rows: [[10]]}} end)

      assert PrestigeHelper.count!("select count(1) from some_table") == 10
    end
  end

  describe "count_query/1" do
    test "returns an error tuple if an error occurs" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:error, "some error"} end)

      assert PrestigeHelper.count("select count(1) from some_table") == {:error, "some error"}
    end

    test "returns the count in an ok tuple" do
      expect(PrestigeMock, :new_session, fn _ -> :connection end)
      expect(PrestigeMock, :execute, fn :connection, _ -> {:ok, %{rows: [[10]]}} end)

      assert PrestigeHelper.count("select count(1) from some_table") == {:ok, 10}
    end
  end
end
