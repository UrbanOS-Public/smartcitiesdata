defmodule AndiWeb.ExtractAuthStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  import Checkov
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions
  alias Floki

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "auth step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()

      auth_step = %{
        context: %{destination: "foo", url: "bar.com", path: ["path"], cacheTtl: 500},
        id: UUID.uuid4(),
        type: "auth",
        sequence: 0
      }

      ingestion =
        TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: [auth_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, auth_step: auth_step]
    end

    test "destination field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_destination = "new_destination"

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_destination") == new_destination
    end

    test "destination field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_destination = ""

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{auth_step.id}_auth_destination_error") == "Please enter a valid destination."
    end

    test "url field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_url = "https://example.com"

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_url") == new_url
    end

    test "url field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_url = ""

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{auth_step.id}_auth_url_error") == "Please enter a valid url - including http:// or https://"
    end

    test "path field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_path = "asdf.qwer"

      form_data = %{
        "path" => new_path
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_path") == new_path
    end

    test "path field shows an error if blank", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_path = ""

      form_data = %{
        "path" => new_path
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{auth_step.id}_auth_path_error") == "Please enter a valid response location."
    end

    test "cacheTtl field has default", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      assert get_value(html, "##{auth_step.id}_auth_cacheTtl") == "0"
    end

    test "cacheTtl field can be altered and saved", %{
      view: view,
      html: html,
      auth_step: auth_step
    } do
      new_cacheTtl = "50"

      form_data = %{
        "cacheTtl" => new_cacheTtl
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{auth_step.id}_auth_cacheTtl") == new_cacheTtl
    end

    test "header fields will keep order after double digits", %{view: view, auth_step: auth_step} do
      new_headers =
        Enum.reduce(0..22, %{}, fn index, acc ->
          view |> element(".url-form__source-headers-add-btn") |> render_click()
          Map.put(acc, "#{index}", %{"key" => "#{index}", "value" => "#{index * 2}"})
        end)

      form_data = %{
        "headers" => new_headers
      }

      view
      |> form("##{auth_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)

      elements = find_elements(html, ".url-form__source-headers-key-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index
      end)

      elements = find_elements(html, ".url-form__source-headers-value-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index * 2
      end)
    end
  end
end
