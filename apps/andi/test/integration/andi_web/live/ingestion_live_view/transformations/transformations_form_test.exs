defmodule AndiWeb.IngestionLiveView.Transformations.TransformationFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

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

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  setup %{conn: conn} do
    dataset = TDG.create_dataset(%{name: "sample_dataset"})

    transformation1 =
      TDG.create_transformation(%{
        name: "sample",
        type: "concatenation",
        parameters: %{"condition" => "false"},
        sequence: 1
      })

    transformation2 =
      TDG.create_transformation(%{
        name: "sample2",
        type: "add",
        parameters: %{"condition" => "false"},
        sequence: 2
      })

    transformation3 =
      TDG.create_transformation(%{
        name: "sample3",
        type: "constant",
        parameters: %{"condition" => "true"},
        sequence: 3
      })

    ingestion =
      TDG.create_ingestion(%{
        id: UUID.uuid4(),
        targetDataset: dataset.id,
        name: "sample_ingestion",
        transformations: [transformation1, transformation2, transformation3]
      })

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

    [view: view, html: html, ingestion: ingestion, conn: conn]
  end

  test "Shows errors for missing name field", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    form_data = %{"name" => ""}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert get_text(html, "##{transformation.id}_transformation_name_error") == "Please enter a valid name."
  end

  test "Header defaults to Transformation when transformation name is cleared from form", %{html: html, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert get_text(html, ".transformation-header") =~ "sample"
  end

  test "Shows errors for missing type field", %{view: view, html: html, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"type" => ""}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert get_text(html, "##{transformation.id}_transformation_type_error") == "Please select a valid type."
  end

  test "can be expanded and collapsed when clicking the header", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    assert has_element?(view, ".transformation-form__section--collapsed")

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    assert has_element?(view, ".transformation-form__section--expanded")

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    assert has_element?(view, ".transformation-form__section--collapsed")
  end

  test "after selecting type, fields appears", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"type" => "add"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert has_element?(view, "#transformation_#{transformation.id}__addends_default")
    assert has_element?(view, "#transformation_#{transformation.id}__targetField_default")
  end

  test "selecting 'under a specific condition' shows the conditional form", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    html = render(view)

    assert has_element?(view, ".transformation-form__condition-fields")
  end

  test "in the condition form, selecting 'static value' will show the static value input field", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Static Value"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert has_element?(view, "#transformation_condition_#{transformation.id}__targetValue")
  end

  test "in the condition form, selecting 'target field' will show the target field input field", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Target Field"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert has_element?(view, "#transformation_condition_#{transformation.id}__targetField")
  end

  test "in the condition form, selecting 'DateTime' as the comparison type will show the date format input fields", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Static Value", "conditionDataType" => "DateTime"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    assert has_element?(view, "#transformation_condition_#{transformation.id}__sourceDateFormat")
    assert has_element?(view, "#transformation_condition_#{transformation.id}__targetDateFormat")
  end

  test "in the condition form, selecting 'Null or Empty' will not show an additional input field", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Null or Empty"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    refute has_element?(view, "#transformation_condition_#{transformation.id}__targetValue")
    refute has_element?(view, "#transformation_condition_#{transformation.id}__targetField")
    refute has_element?(view, "#transformation_condition_#{transformation.id}__sourceDateFormat")
    refute has_element?(view, "#transformation_condition_#{transformation.id}__targetDateFormat")
  end

  test "in the condition form, selecting 'static value' will allow equals, not equals, greater than, or less than comparisons", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Static Value"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__comparison") |> render()
    assert options_html =~ "Is Equal To"
    assert options_html =~ "Is Not Equal To"
    assert options_html =~ "Is Greater Than"
    assert options_html =~ "Is Less Than"
  end

  test "in the condition form, selecting 'target field' will allow equals, not equals, greater than, or less than comparisons", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Target Field"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__comparison") |> render()
    assert options_html =~ "Is Equal To"
    assert options_html =~ "Is Not Equal To"
    assert options_html =~ "Is Greater Than"
    assert options_html =~ "Is Less Than"
  end

  test "in the condition form, selecting 'Null or Empty' will allow equals and not equals comparisons", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionCompareTo" => "Null or Empty"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__comparison") |> render()
    assert options_html =~ "Is Equal To"
    assert options_html =~ "Is Not Equal To"
    refute options_html =~ "Is Greater Than"
    refute options_html =~ "Is Less Than"
  end

  test "in the condition form, when no compare to type selected yet, show all comparison options", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"condition" => "true"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__comparison") |> render()
    assert options_html =~ "Is Equal To"
    assert options_html =~ "Is Not Equal To"
    assert options_html =~ "Is Greater Than"
    assert options_html =~ "Is Less Than"
  end

  test "in the condition form, selecting 'Is Equal To' will show all compare to types", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionOperation" => "Is Equal To"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__compareTo") |> render()
    assert options_html =~ "Static Value"
    assert options_html =~ "Target Field"
    assert options_html =~ "Null or Empty"
  end

  test "in the condition form, selecting 'Is Not Equal To' will show all compare to types", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionOperation" => "Is Not Equal To"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__compareTo") |> render()
    assert options_html =~ "Static Value"
    assert options_html =~ "Target Field"
    assert options_html =~ "Null or Empty"
  end

  test "in the condition form, selecting 'Is Greater Than' will show static and target field compare to types", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionOperation" => "Is Greater Than"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__compareTo") |> render()
    assert options_html =~ "Static Value"
    assert options_html =~ "Target Field"
    refute options_html =~ "Null or Empty"
  end

  test "in the condition form, selecting 'Is Less Than' will show static and target field compare to types", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"conditionOperation" => "Is Less Than"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__compareTo") |> render()
    assert options_html =~ "Static Value"
    assert options_html =~ "Target Field"
    refute options_html =~ "Null or Empty"
  end

  test "in the condition form, when no condition operation selected, will show all compare to options", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"condition" => "true"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    options_html = element(view, "#transformation_condition_#{transformation.id}__compareTo") |> render()
    assert options_html =~ "Static Value"
    assert options_html =~ "Target Field"
    assert options_html =~ "Null or Empty"
  end

  test "in the constant transformation form, when 'null / empty' type is selected, the value field is not shown", %{
    view: view,
    ingestion: ingestion
  } do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "constant" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"valueType" => "null / empty"}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    refute has_element?(view, "#transformation_#{transformation.id}__newValue_default")
  end

  data_test "when selecting #{type}, its respective fields will show", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    view
    |> element("#transformation_#{transformation.id}__header")
    |> render_click()

    form_data = %{"type" => type}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)

    for field <- fields do
      assert has_element?(view, "#transformation_#{transformation.id}__#{field}_default")
    end

    where([
      [:type, :fields],
      ["add", ["addends", "targetField"]],
      ["concatenation", ["sourceFields", "separator", "targetField"]],
      ["constant", ["newValue", "valueType", "targetField"]],
      ["conversion", ["field", "sourceType", "targetType"]],
      ["datetime", ["sourceField", "sourceFormat", "targetField", "targetFormat"]],
      ["division", ["targetField", "dividend", "divisor"]],
      ["multiplication", ["targetField", "multiplicands"]],
      ["regex_extract", ["sourceField", "regex", "targetField"]],
      ["regex_replace", ["sourceField", "regex", "replacement"]],
      ["remove", ["sourceField"]],
      ["subtract", ["targetField", "subtrahends", "minuend"]],
      ["regex_replace", ["sourceField", "regex", "replacement"]]
    ])
  end
end
