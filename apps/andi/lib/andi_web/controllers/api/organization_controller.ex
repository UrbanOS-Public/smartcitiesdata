defmodule AndiWeb.API.OrganizationController do
  @moduledoc """
  Creates new organizations and retrieves existing ones in ViewState.
  """
  use AndiWeb, :controller

  require Logger
  alias SmartCity.Organization
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore
  import SmartCity.Event, only: [organization_update: 0]

  access_levels(
    create: [:private],
    get_all: [:private],
    add_users_to_organization: [:private]
  )

  @instance_name Andi.instance_name()

  @doc """
  Parse a data message to create a new organization to store in ViewState
  """
  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, _params) do
    message =
      conn.body_params
      |> remove_blank_keys()
      |> add_uuid()

    with :ok <- ensure_new_org_name(message["id"], message["orgName"]),
         :ok <- ensure_new_org_id(message["id"]),
         {:ok, organization} <- Organization.new(message),
         :ok <- write_organization(organization) do
      conn
      |> put_status(:created)
      |> json(organization)
    else
      error ->
        Logger.error("Failed to create organization: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json("Unable to process your request: #{inspect(error)}")
    end
  end

  defp ensure_new_org_id(id) do
    case Organizations.get(id) do
      nil ->
        :ok

      _ ->
        Logger.error("id #{id} already exists.")
        %RuntimeError{message: "id #{id} already exists."}
    end
  end

  defp ensure_new_org_name(id, org_name) do
    case Organizations.is_unique?(id, org_name) do
      false ->
        Logger.error("orgName #{org_name} already exists.")
        %RuntimeError{message: "orgName #{org_name} already exists."}

      _ ->
        :ok
    end
  end

  defp remove_blank_keys(message) do
    message
    |> Enum.filter(fn {_, v} -> v != "" end)
    |> Map.new()
  end

  defp add_uuid(message) do
    uuid = UUID.uuid4()

    Map.merge(message, %{"id" => uuid}, fn _k, v1, _v2 -> v1 end)
  end

  defp write_organization(org) do
    Andi.Schemas.AuditEvents.log_audit_event(:api, organization_update(), org)

    case Brook.Event.send(@instance_name, organization_update(), :andi, org) do
      :ok ->
        :ok

      error ->
        error
    end
  end

  @doc """
  Retrieve all existing organizations stored in ViewState
  """
  @spec get_all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def get_all(conn, _params) do
    case OrgStore.get_all() do
      {:ok, orgs} ->
        conn
        |> put_status(:ok)
        |> json(orgs)

      {_, error} ->
        Logger.error("Failed to retrieve organizations: #{inspect(error)}")

        conn
        |> put_status(:not_found)
        |> json("Unable to process your request")
    end
  end

  @doc """
  Sends a user:organization:associate event
  """
  def add_users_to_organization(conn, %{"org_id" => org_id, "users" => user_ids}) do
    retrieved_users = Enum.map(user_ids, fn id -> {id, Andi.Schemas.User.get_by_subject_id(id)} end)

    with false <- Enum.any?(retrieved_users, fn {_id, user} -> user == nil end),
         users <- Enum.map(retrieved_users, fn {_id, user} -> user end),
         :ok <- Andi.Services.UserOrganizationAssociateService.associate(org_id, users) do
      conn
      |> put_status(200)
      |> json(conn.body_params)
    else
      {:error, :invalid_org} ->
        conn
        |> put_status(400)
        |> json("The organization #{org_id} does not exist")

      {:error, _} ->
        conn
        |> put_status(500)
        |> put_view(AndiWeb.ErrorView)
        |> render("500.json")

      true ->
        missing_user_ids =
          retrieved_users
          |> Enum.filter(fn {_id, user} -> user == nil end)
          |> Enum.map(fn {id, _user} -> id end)

        conn
        |> put_status(400)
        |> json("The user(s) in this list: [#{Enum.join(missing_user_ids, ",")}] do not exist. No users were added to organizations.")
    end
  end
end
