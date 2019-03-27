defmodule Andi.LdapUtilsTest do
  use ExUnit.Case
  alias Andi.LdapUtils

  describe "encode_dn!/1" do
    test "encodes a keyword list into a distinguished name" do
      kwdn = [cn: "foo", cn: "bar", ou: "baz"]
      assert LdapUtils.encode_dn!(kwdn) == "cn=foo,cn=bar,ou=baz"
    end

    test "raises error if argument cannot be encoded to dn" do
      assert_raise FunctionClauseError, fn -> LdapUtils.encode_dn!("foo") end
      assert_raise FunctionClauseError, fn -> LdapUtils.encode_dn!([{"x", "y"}]) end
      assert_raise FunctionClauseError, fn -> LdapUtils.encode_dn!(["acb", 123]) end
    end
  end

  describe "decode_dn!/1" do
    test "decodes a simple dn string into a keyword list" do
      dn = "cn=foo"
      assert LdapUtils.decode_dn!(dn) == [cn: "foo"]
    end

    test "decodes a multi-element dn into a keyword list" do
      dn = "cn=foo,cn=bar,dc=baz"
      assert LdapUtils.decode_dn!(dn) == [cn: "foo", cn: "bar", dc: "baz"]
    end

    test "raises error if argument cannot be decoded into a kwdn" do
      assert_raise RuntimeError, fn -> LdapUtils.decode_dn!("foobar,foobaz") end
    end
  end
end
