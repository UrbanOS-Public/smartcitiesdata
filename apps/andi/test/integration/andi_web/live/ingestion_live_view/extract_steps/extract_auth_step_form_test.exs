defmodule AndiWeb.ExtractAuthStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]
  import SmartCity.Event, only: [ingestion_update: 0]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias IngestionHelpers
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.ExtractSteps
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"
  @instance_name Andi.instance_name()

  describe "updating headers" do
    setup do
      context = %{
        url: "test.com",
        headers: %{"barl" => "biz", "yar" => "har"},
        path: ["some", "dest"],
        destination: "dest",
        cacheTtl: 1_000,
        body: "[]"
      }

      {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      [ingestion: ingestion, extract_step_id: extract_step_id]
    end

    test "new key/value inputs are added when add button is pressed for headers", %{
      conn: conn,
      ingestion: ingestion,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 2
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 2

      add_button = element(extract_steps_form_view, "#step-#{extract_step_id} .url-form__source-headers-add-btn")
      html = render_click(add_button)

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 3
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 3
    end

    test "key/value inputs are deleted when delete button is pressed for headers", %{
      conn: conn,
      ingestion: ingestion,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_steps_form_view = find_live_child(view, "extract_step_form_editor")

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 2
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 2

      btn_id =
        get_attributes(html, ".url-form__source-headers-delete-btn", "phx-value-id")
        |> hd()

      button_selector = "#step-#{extract_step_id} .url-form__source-headers-delete-btn[phx-value-id='#{btn_id}']"

      del_button = element(extract_steps_form_view, button_selector)

      html = render_click(del_button)

      [key_input] = html |> get_attributes(".url-form__source-headers-key-input", "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(".url-form__source-headers-value-input", "class")
      refute btn_id =~ value_input
    end

    test "does not have key/value inputs when extract step has no headers", %{conn: conn} do
      context = %{"headers" => %{}}
      {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      assert html |> find_elements(".url-form__source-headers-key-input") |> Enum.empty?()
      assert html |> find_elements(".url-form__source-headers-value-input") |> Enum.empty?()
    end
  end

  test "required url field displays proper error message", %{conn: conn} do
    context = %{"url" => "123.com"}
    {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()

    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"url" => ""}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "#url-error-msg") == "Please enter a valid url - including http:// or https://"
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    context = %{
      url: "123.com",
      body: "",
      headers: %{"api-key" => "to-my-heart"},
      cacheTtl: 1_000,
      destination: "dest",
      path: ["blah", "blah"]
    }

    {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()

    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{field => value}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "##{field}-error-msg") == error

    where([
      [:field, :value, :error],
      ["headers", %{"0" => %{"key" => "", "value" => "where is it?!"}}, "Please enter valid key(s)."],
      ["body", "this is invalid json", "Please enter valid JSON"]
    ])
  end

  test "body passes validation with valid json", %{conn: conn} do
    context = %{
      url: "123.com",
      body: "",
      headers: %{"api-key" => "to-my-heart"}
    }

    {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()
    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    form_data = %{"body" => "[{\"bob\": 1}]", "action" => "POST"}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "#body-error-msg") == ""
  end

  test "converts dot notation path for changeset", %{conn: conn} do
    context = %{
      path: ["a", "b", "c"]
    }

    {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()
    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    assert get_value(html, ".extract-auth-step-form__path input") == "a.b.c"

    form_data = %{"path" => "x.y.z"}
    render_change(es_form, %{"form_data" => form_data})

    render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert ExtractSteps.get(extract_step_id) |> get_in([:context, "path"]) == ["x", "y", "z"]
    end)
  end

  test "converts cacheTtl to minutes", %{conn: conn} do
    context = %{
      cacheTtl: 900_000
    }

    {:ok, ingestion} = IngestionHelpers.create_with_auth_extract_step(context) |> IngestionHelpers.save_ingestion()
    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_steps_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_steps_form_view, "#step-#{extract_step_id} form")

    assert get_value(html, ".extract-auth-step-form__cacheTtl input") == "15"

    form_data = %{"cacheTtl" => "20"}
    render_change(es_form, %{"form_data" => form_data})

    render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert ExtractSteps.get(extract_step_id) |> get_in([:context, "cacheTtl"]) == 1_200_000
    end)
  end
end
