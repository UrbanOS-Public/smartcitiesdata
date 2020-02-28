defmodule Pipeline.Writer.TableWriter.Helper.PrestigeHelperTest do
  use ExUnit.Case
  use Placebo

  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  @expected_table_data %{
    "column_1" => "some column_1 data",
    "column_2" => "some column_2 data"
  }

  @tag capture_log: true
  test "should return the data by executing the when the query statement is passed" do
    allow(Prestige.new_session(any()), return: :connection)
    allow(Prestige.execute(any(), any()), return: @expected_table_data)
    assert @expected_table_data == PrestigeHelper.execute_query("whatever")
  end

  test "should return error when error occurs while executing the query" do
    expected_error = {:error, "some error"}
    allow(Prestige.new_session(any()), return: :connection)
    allow(Prestige.execute(any(), any()), return: expected_error)
    assert expected_error == PrestigeHelper.execute_query("whatever")
  end

  test "should attempt to execute query asynchronously" do
    allow(Prestige.new_session(any()), return: :connection)
    allow(Prestige.execute(any(), any()), return: @expected_table_data)

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

    allow(Prestige.new_session(any()), return: expected_session)
    assert expected_session == PrestigeHelper.create_session()
  end
end
