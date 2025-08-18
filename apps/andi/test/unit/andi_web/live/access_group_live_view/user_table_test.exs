defmodule AndiWeb.AccessGroupLiveView.UserTableTest do
  use AndiWeb.Test.AuthConnCase.UnitCase

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  @moduletag timeout: 5000

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.AccessGroup
  alias Andi.Schemas.User

  @endpoint AndiWeb.Endpoint
  @url_path "/access-groups"
  @user UserHelpers.create_user()
  @access_group TDG.create_access_group(%{})

  setup do
    # Set up :meck for modules without dependency injection
    modules_to_mock = [Andi.Repo, User, AccessGroups, Guardian.DB.Token]
    
    # Clean up any existing mocks first
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.unload(module)
      catch
        _, _ -> :ok
      end
    end)
    
    # Set up fresh mocks
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)
    
    # Default expectations - provide flexible fallbacks
    :meck.expect(Andi.Repo, :get_by, fn Andi.Schemas.User, _ -> @user end)
    :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
    :meck.expect(User, :get_all, fn -> [@user] end)
    :meck.expect(User, :get_by_subject_id, fn subject_id -> 
      # Handle auth system subject_id and test-specific ones
      case subject_id do
        id when is_binary(id) -> @user  # Return default user for any string subject_id
        _ -> @user
      end
    end)
    :meck.expect(AccessGroups, :update, fn _ -> %AccessGroup{id: @access_group.id, name: @access_group.name} end)
    :meck.expect(AccessGroups, :get, fn _ -> %AccessGroup{id: @access_group.id, name: @access_group.name} end)
    :meck.expect(Guardian.DB.Token, :find_by_claims, fn _ -> nil end)
    
    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
    end)
    
    :ok
  end

  describe "Basic associated users table load" do
    test "shows \"No Associated Users\" when there are no rows to show", %{conn: conn} do
      # Override the default Andi.Repo expectations for this test
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [], id: @access_group.id} end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{@access_group.id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ "No Associated Users"
    end

    test "shows an associated user", %{conn: conn} do
      org_title = "Constellations R Us"

      access_group_id = @access_group.id

      user_subject_id = "auth0|someStringOfNumbers"

      user = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_subject_id,
        name: "Ophiuchus",
        email: "ophiuchus@constellations.net",
        organizations: [%Andi.InputSchemas.Organization{orgTitle: "Constellations R Us"}]
      }

      # Override expectations for this test
      :meck.expect(Andi.Repo, :preload, fn _, [:datasets, :users] -> %{datasets: [], users: [user], id: access_group_id} end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(User, :get_by_subject_id, fn
        ^user_subject_id -> user
        _ -> @user  # Fallback for auth system subject_id
      end)
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ user.name
      assert get_text(html, ".access-groups-sub-table__cell") =~ org_title
    end

    test "shows multiple associated users", %{conn: conn} do
      access_group_id = @access_group.id

      user_1_subject_id = "auth0|someStringOfNumbers"

      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_1_subject_id,
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2_subject_id = "auth0|someStringOfNumbersAlso"

      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_2_subject_id,
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      # Override expectations for this test
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [user_1, user_2], id: access_group_id} end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(User, :get_by_subject_id, fn
        ^user_1_subject_id -> user_1
        ^user_2_subject_id -> user_2
        _ -> @user
      end)
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")

      assert get_text(html, ".access-groups-sub-table__cell") =~ user_1.name
      assert get_text(html, ".access-groups-sub-table__cell") =~ user_2.name
    end

    test "shows a remove button for each user", %{conn: conn} do
      access_group_id = @access_group.id

      user_1_subject_id = "auth0|someStringOfNumbers"

      user_1 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_1_subject_id,
        name: "Penny",
        email: "penny@dogs.com",
        organizations: []
      }

      user_2_subject_id = "auth0|someStringOfNumbersAlso"

      user_2 = %Andi.Schemas.User{
        id: UUID.uuid4(),
        subject_id: user_2_subject_id,
        name: "Hazel",
        email: "hazel@dogs.com",
        organizations: []
      }

      # Override expectations for this test
      :meck.expect(Andi.Repo, :preload, fn _, _ -> %{datasets: [], users: [user_1, user_2], id: access_group_id} end)
      :meck.expect(Andi.Repo, :get, fn Andi.InputSchemas.AccessGroup, _ -> [] end)
      :meck.expect(User, :get_by_subject_id, fn
        ^user_1_subject_id -> user_1
        ^user_2_subject_id -> user_2
        _ -> @user
      end)
      
      assert {:ok, _view, html} = live(conn, "#{@url_path}/#{access_group_id}")
      text = get_text(html, ".access-groups-sub-table__cell")
      results = Regex.scan(~r/Remove/, text)

      assert length(results) == 2
    end
  end
end
