defmodule AndiWeb.ExtractSecretFormTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Phoenix.ConnTest
  use Placebo
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets.ExtractSecretStep

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [find_elements: 2, get_text: 2, get_attributes: 3]

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"
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
      secret_extract_step = %{
        type: "secret",
        context: %{
          destination: "bob_field",
          sub_key: "secret-key"
        }
      }

      dataset = DatasetHelpers.create_dataset(%{technical: %{extractSteps: [secret_extract_step]}})

      extract_step_id =
        dataset
        |> get_in([:technical, :extractSteps])
        |> hd()
        |> Map.get(:id)

      allow(Andi.InputSchemas.Datasets.get(dataset.id), return: dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")

      [extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id]
    end

    test "displays error for missing fields", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      form_data = %{"destination" => ""}
      html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

      error_text = get_text(html, "#destination-error-msg")
      assert error_text != ""
    end

    test "disables add button while form is invalid", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      form_data = %{"destination" => ""}
      html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

      refute get_attributes(html, ".btn", "disabled") |> Enum.empty?()
    end

    test "displays success message when secret is saved", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      expect(Andi.SecretService.write("#{extract_step_id}___bob", %{"bob" => "secret_value"}), return: {:ok, :na})

      render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => %{"destination" => "bob"}})
      html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "save_secret", %{"secret" => "secret_value"})

      success_text = get_text(html, ".secret-status-msg")
      assert success_text == "Secret saved successfully!"
    end

    test "displays error message when secret cannot be saved", %{extract_steps_form_view: extract_steps_form_view, extract_step_id: extract_step_id} do
      expect(Andi.SecretService.write("#{extract_step_id}___bob", %{"bob" => "secret_value"}), return: {:error, :na})

      render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => %{"destination" => "bob"}})
      html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "save_secret", %{"secret" => "secret_value"})

      success_text = get_text(html, ".secret-status-msg")
      assert success_text == "Secret save failed, contact your system administrator."
    end
  end

  defp get_extract_step_id(dataset) do
    dataset
    |> get_in([:technical, :extractSteps])
    |> hd()
    |> Map.get(:id)
  end
end
