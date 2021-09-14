defmodule Schemas.UserOrgAssocTest do
  use RaptorWeb.ConnCase
  alias Raptor.Schemas.UserOrgAssoc

  test "convert from SmartCity event to Raptor user-org association schema", %{conn: conn} do
    expected = %UserOrgAssoc{user_id: "user", org_id: "my_cool_org", email: "user@email.com"}

    {:ok, actualUserOrgAssociation} =
      UserOrgAssoc.from_associate_event(%SmartCity.UserOrganizationAssociate{
        subject_id: "user",
        org_id: "my_cool_org",
        email: "user@email.com"
      })

    assert expected == actualUserOrgAssociation
  end
end
