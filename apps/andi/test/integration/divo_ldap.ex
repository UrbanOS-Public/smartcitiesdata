defmodule Andi.DivoLdap do
  @moduledoc """
  Defines a simple ldap server compatible with divo
  for building a docker-compose file.
  """

  def gen_stack(_envar \\ []) do
    %{
      ldap: %{
        image: "osixia/openldap",
        ports: ["389:389", "636:636"],
        healthcheck: %{
          test: [
            "CMD-SHELL",
            "ldapsearch -x -H ldap://localhost -b dc=example,dc=org -D 'cn=admin,dc=example,dc=org' -w admin"
          ],
          interval: "5s",
          timeout: "20s",
          retries: 3
        }
      }
    }
  end
end
