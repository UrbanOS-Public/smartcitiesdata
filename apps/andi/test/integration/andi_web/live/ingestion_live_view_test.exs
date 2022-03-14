defmodule AndiWeb.IngestionLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_texts: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Ingestion

  @instance_name Andi.instance_name()

  @url_path "/ingestions"

  describe "public user access" do
    test "public users cannot view or edit ingestions", %{public_conn: conn} do
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
    test "curators can view all the users", %{curator_conn: conn} do
      assert {:ok, view, html} = live(conn, @url_path)
    end
  end
end
