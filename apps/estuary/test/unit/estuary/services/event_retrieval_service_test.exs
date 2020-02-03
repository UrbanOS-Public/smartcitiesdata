defmodule Estuary.Services.EventRetrievalServiceTest do
  use ExUnit.Case
  use Placebo

  alias Estuary.Services.EventRetrievalService
  alias Estuary.Query.Helper.PrestigeHelper

  @tag capture_log: true
  test "should return the events from the table" do
    expected_events = [
      %{
        "author" => "Author-2020-01-21 23:29:20.171519Z",
        "create_ts" => 1_579_649_360,
        "data" => "Data-2020-01-21 23:29:20.171538Z",
        "type" => "Type-2020-01-21 23:29:20.171543Z"
      },
      %{
        "author" => "Author-2020-01-21 23:25:52.522084Z",
        "create_ts" => 1_579_649_152,
        "data" => "Data-2020-01-21 23:25:52.522107Z",
        "type" => "Type-2020-01-21 23:25:52.522111Z"
      }
    ]

    allow(PrestigeHelper.execute_query(any()), return: {:ok, expected_events})
    assert expected_events = EventRetrievalService.get_all()
  end
end
