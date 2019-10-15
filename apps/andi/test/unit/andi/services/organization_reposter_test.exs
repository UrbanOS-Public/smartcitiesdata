defmodule Andi.Services.OrganizationReposterTest do
  use ExUnit.Case
  use Placebo
  alias Andi.Services.OrganizationReposter

  @tag capture_log: true
  test "errors when brook cannot get all values" do
    error = {:error, "Bad things happened"}
    allow(Brook.get_all_values(any(), :org), return: error)
    assert OrganizationReposter.repost_all_orgs() == error
  end

  @tag capture_log: true
  test "errors when brook cannot send an update" do
    allow(Brook.get_all_values(any(), :org), return: {:ok, [%{}]})
    allow(Brook.Event.send(any(), any(), :andi, any()), return: {:error, "does not matter"})
    assert OrganizationReposter.repost_all_orgs() == {:error, "Failed to repost all organizations"}
  end

end
