defmodule UserHelpers do
  @moduledoc false

  alias Andi.Schemas.User

  def create_user(id \\ "123", subject_id \\ "auth0|test", email \\ "test@example.com") do
    %User{id: id, subject_id: subject_id, email: email}
  end
end
