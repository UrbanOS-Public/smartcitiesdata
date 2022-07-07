defmodule AndiWeb.ExtractSecretFormTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User
  alias IngestionHelpers

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2, get_attributes: 3]

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"
  @user UserHelpers.create_user()

  setup do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "date extract step form" do
    setup %{conn: conn} do
      allow(Andi.Repo.all(any()), return: [])

      default_context = %{
        destination: "bob_field",
        sub_key: "secret-key"
      }

      %{ingestion: ingestion} = IngestionHelpers.create_with_secret_extract_step(default_context) |> IngestionHelpers.mock_repo_get()

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

      [extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id]
    end

    test "displays error for missing fields", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      form_data = %{"destination" => ""}
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      html = render_change(es_form, %{"form_data" => form_data})

      error_text = get_text(html, "#destination-error-msg")
      assert error_text != ""
    end

    test "disables add button while form is invalid", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      form_data = %{"destination" => ""}
      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

      html = render_change(es_form, %{"form_data" => form_data})

      refute get_attributes(html, ".btn", "disabled") |> Enum.empty?()
    end

    test "displays success message when secret is saved", %{
      extract_steps_form_view: extract_steps_form_view,
      extract_step_id: extract_step_id
    } do
      expect(Andi.SecretService.write("#{extract_step_id}___bob", %{"bob" => "secret_value"}), return: {:ok, :na})

      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")
      add_secret_button = element(extract_steps_form_view, "#step-#{extract_step_id} button", "Add")

      render_change(es_form, %{"form_data" => %{"destination" => "bob", "secret_value" => "secret_value"}})
      html = render_click(add_secret_button)

      success_text = get_text(html, ".secret__status-msg")
      assert success_text == "Secret saved successfully!"
    end

    test "displays error message when secret cannot be saved", %{
      extract_steps_form_view: extract_steps_form_view,
      extract_step_id: extract_step_id
    } do
      expect(Andi.SecretService.write("#{extract_step_id}___bob", %{"bob" => "secret_value"}), return: {:error, :na})

      es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")
      add_secret_button = element(extract_steps_form_view, "#step-#{extract_step_id} button", "Add")

      render_change(es_form, %{"form_data" => %{"destination" => "bob", "secret_value" => "secret_value"}})

      html = render_click(add_secret_button)

      success_text = get_text(html, ".secret__status-msg")
      assert success_text == "Secret save failed, contact your system administrator."
    end
  end
end
