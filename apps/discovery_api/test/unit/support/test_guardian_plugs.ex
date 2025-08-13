defmodule DiscoveryApiWeb.Test.TestGuardianPlugs do
  @moduledoc """
  Test-only Guardian plug implementations that bypass database requirements
  """
  
  alias DiscoveryApiWeb.Test.TestGuardian
  
  defmodule VerifyHeader do
    @moduledoc "Test version of Auth.Guardian.Plug.VerifyHeader"
    
    def init(opts), do: opts
    
    def call(conn, _opts) do
      # In test mode, skip token verification
      TestGuardian.verify_header(conn, [])
    end
  end
  
  defmodule LoadResource do
    @moduledoc "Test version of Guardian.Plug.LoadResource"
    
    def init(opts), do: opts
    
    def call(conn, opts) do
      # In test mode, just pass through - allow_blank option is ignored
      TestGuardian.load_resource(conn, opts)
    end
  end
  
  defmodule EnsureAuthenticated do
    @moduledoc "Test version of Guardian.Plug.EnsureAuthenticated"
    
    def init(opts), do: opts
    
    def call(conn, _opts) do
      TestGuardian.ensure_authenticated(conn, [])
    end
  end
  
  defmodule Pipeline do
    @moduledoc "Test version of Guardian.Plug.Pipeline"
    
    def init(opts), do: opts
    
    def call(conn, _opts) do
      # In test mode, skip pipeline setup
      conn
    end
  end
end