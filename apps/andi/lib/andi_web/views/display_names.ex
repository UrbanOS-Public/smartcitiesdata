defmodule AndiWeb.Views.DisplayNames do
  @moduledoc false

  @display_names %{
    id: "ID",
    benefitRating: "Benefit",
    cadence: "Cadence",
    contactEmail: "Maintainer Email",
    contactName: "Maintainer Name",
    dataJsonUrl: "Data JSON URL",
    dataTitle: "Dataset Title",
    description: "Description",
    format: "Format",
    homepage: "Homepage URL",
    issuedDate: "Release Date",
    itemType: "Item Type",
    keywords: "Keywords",
    language: "Language",
    license: "License",
    logoUrl: "Logo URL",
    modifiedDate: "Last Updated",
    orgTitle: "Organization Title",
    orgId: "Organization",
    publishFrequency: "Update Frequency",
    spatial: "Spatial Boundaries",
    temporal: "Temporal Boundaries",
    dataName: "Data Name",
    orgName: "Organization Name",
    private: "Level of Access",
    riskRating: "Risk",
    schema: "Schema",
    selector: "Selector",
    sourceFormat: "Source Format",
    sourceHeaders: "Headers",
    sourceQueryParams: "Query Parameters",
    sourceType: "Source Type",
    sourceUrl: "Base URL",
    topLevelSelector: "Top Level Selector",
    name: "Name",
    type: "Type",
    week: "Week",
    year: "Year",
    month: "Month",
    day: "Day",
    hour: "Hour",
    minute: "Minute",
    second: "Second",
    date: "Date",
    time: "Time"
  }

  def get(field_key) do
    Map.get(@display_names, field_key)
  end
end
