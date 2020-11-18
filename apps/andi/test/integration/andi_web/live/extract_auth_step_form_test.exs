defmodule AndiWeb.ExtractAuthStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias Andi.Services.UrlTest
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.ExtractSteps
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "updating headers" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "auth",
                context: %{
                  url: "test.com",
                  headers: %{"barl" => "biz", "yar" => "har"},
                  path: ["some", "dest"],
                  destination: "dest",
                  cacheTtl: 1_000,
                  body: "[]"
                }
              }
            ]
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)
      extract_step_id = get_extract_step_id(andi_dataset, 0)

      [dataset: andi_dataset, extract_step_id: extract_step_id]
    end

    test "new key/value inputs are added when add button is pressed for headers", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 2
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 2

      html = render_click([extract_steps_form_view, "#step-#{extract_step_id}"], "add", %{"field" => "headers"})

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 3
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 3
    end

    test "key/value inputs are deleted when delete button is pressed for headers", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")

      assert html |> find_elements(".url-form__source-headers-key-input") |> length() == 2
      assert html |> find_elements(".url-form__source-headers-value-input") |> length() == 2

      btn_id =
        get_attributes(html, ".url-form__source-headers-delete-btn", "phx-value-id")
        |> hd()

      html = render_click([extract_steps_form_view, "#step-#{extract_step_id}"], "remove", %{"id" => btn_id, "field" => "headers"})

      [key_input] = html |> get_attributes(".url-form__source-headers-key-input", "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(".url-form__source-headers-value-input", "class")
      refute btn_id =~ value_input
    end

    test "does not have key/value inputs when dataset extract step has no headers", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{"type" => "auth", "context" => %{"headers" => %{}}}]}})
      {:ok, andi_dataset} = Datasets.update(dataset)
      extract_step_id = get_extract_step_id(andi_dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")

      html = render([extract_steps_form_view, "#step-#{extract_step_id}"])

      assert html |> find_elements(".url-form__source-headers-key-input") |> Enum.empty?()
      assert html |> find_elements(".url-form__source-headers-value-input") |> Enum.empty?()
    end
  end

  test "required url field displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "auth",
              context: %{
                url: "123.com"
              }
            }
          ]
        }
      })

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"url" => ""}

    html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "#url-error-msg") == "Please enter a valid url."
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "auth",
              context: %{
                url: "123.com",
                body: "",
                headers: %{"api-key" => "to-my-heart"},
                cacheTtl: 1_000,
                destination: "dest",
                path: ["blah", "blah"]
              }
            }
          ]
        }
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)

    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{field => value}

    html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "##{field}-error-msg") == error

    where([
      [:field, :value, :error],
      ["headers", %{"0" => %{"key" => "", "value" => "where is it?!"}}, "Please enter valid key(s)."],
      ["body", "this is invalid json", "Please enter valid JSON"]
    ])
  end

  test "body passes validation with valid json", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "auth",
              context: %{
                url: "123.com",
                body: "",
                headers: %{"api-key" => "to-my-heart"}
              }
            }
          ]
        }
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)
    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"body" => "[{\"bob\": 1}]", "action" => "POST"}

    html = render_change([extract_steps_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "#body-error-msg") == ""
  end

  test "converts dot notation path for changeset", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "auth",
              context: %{
                path: ["a", "b", "c"]
              }
            }
          ]
        }
      })

    {:ok, andi_dataset} = Datasets.update(smrt_dataset)
    extract_step_id = get_extract_step_id(andi_dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
    extract_steps_form_view = find_child(view, "extract_step_form_editor")

    assert get_value(html, ".extract-auth-step-form__path input") == "a.b.c"

    form_data = %{"path" => "x.y.z"}
    render_change([extract_steps_form_view, "#step-#{extract_step_id}"], "validate", %{"form_data" => form_data})

    html = render_click(extract_steps_form_view, "save")

    eventually(fn ->
      assert ExtractSteps.get(extract_step_id) |> IO.inspect() |> get_in([:context, "path"]) == ["x", "y", "z"]
    end)
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
