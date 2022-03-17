defmodule AndiWeb.AccessGroupLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups

  @instance_name Andi.instance_name()

  @url_path "/access-groups"

  describe "public user access" do
    test "public users cannot view or edit access groups", %{public_conn: conn} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path)
    end
  end

  describe "curator users access" do
    test "curators can view all the access groups", %{curator_conn: conn} do
      assert {:ok, view, html} = live(conn, @url_path)
    end
  end
end
