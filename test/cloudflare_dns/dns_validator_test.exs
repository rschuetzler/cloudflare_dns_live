defmodule CloudflareDns.DNSValidatorTest do
  use ExUnit.Case, async: true
  alias CloudflareDns.{DNSValidator, CloudflareClient.DNSRecord}

  describe "validate_record/1" do
    test "validates a valid A record" do
      attrs = %{
        "type" => "A",
        "name" => "test",
        "content" => "192.0.2.1"
      }

      assert {:ok, validated} = DNSValidator.validate_record(attrs)
      assert validated["name"] == "test.is404.net"
    end

    test "validates a valid CNAME record" do
      attrs = %{
        "type" => "CNAME",
        "name" => "alias",
        "content" => "example.com"
      }

      assert {:ok, validated} = DNSValidator.validate_record(attrs)
      assert validated["name"] == "alias.is404.net"
    end

    test "rejects invalid record types" do
      attrs = %{
        "type" => "MX",
        "name" => "test",
        "content" => "10 mail.example.com"
      }

      assert {:error, errors} = DNSValidator.validate_record(attrs)
      assert "Record type must be one of: A, CNAME" in errors
    end

    test "rejects www subdomain" do
      attrs = %{
        "type" => "A",
        "name" => "www",
        "content" => "192.0.2.1"
      }

      assert {:error, errors} = DNSValidator.validate_record(attrs)
      assert "Cannot create records for www, @ (root domain), or empty names" in errors
    end

    test "rejects wildcard domains" do
      attrs = %{
        "type" => "A",
        "name" => "*.test",
        "content" => "192.0.2.1"
      }

      assert {:error, errors} = DNSValidator.validate_record(attrs)
      assert "Wildcard domains are not allowed" in errors
    end

    test "rejects invalid IPv4 for A records" do
      attrs = %{
        "type" => "A",
        "name" => "test",
        "content" => "999.999.999.999"
      }

      assert {:error, errors} = DNSValidator.validate_record(attrs)
      assert "A records must contain a valid IPv4 address (e.g., 192.0.2.1)" in errors
    end

    test "rejects invalid domain for CNAME records" do
      attrs = %{
        "type" => "CNAME",
        "name" => "test",
        "content" => "not_a_domain"
      }

      assert {:error, errors} = DNSValidator.validate_record(attrs)
      assert "CNAME records must contain a valid domain name (e.g., example.com)" in errors
    end
  end

  describe "can_modify_record?/1" do
    test "allows modification of student records" do
      record = %DNSRecord{comment: "STUDENT"}
      assert DNSValidator.can_modify_record?(record)
    end

    test "prevents modification of protected records" do
      record = %DNSRecord{comment: "KEEP"}
      refute DNSValidator.can_modify_record?(record)
    end
  end

  describe "student_record?/1" do
    test "identifies student records" do
      record = %DNSRecord{comment: "STUDENT"}
      assert DNSValidator.student_record?(record)
    end

    test "identifies non-student records" do
      record = %DNSRecord{comment: "KEEP"}
      refute DNSValidator.student_record?(record)
    end
  end

  describe "get_record_info/1" do
    test "returns A record information" do
      info = DNSValidator.get_record_info("A")
      assert info.type == "A"
      assert info.name == "Address Record"
      assert String.contains?(info.description, "IPv4")
    end

    test "returns CNAME record information" do
      info = DNSValidator.get_record_info("CNAME")
      assert info.type == "CNAME"
      assert info.name == "Canonical Name Record"
      assert String.contains?(info.description, "alias")
    end

    test "returns empty map for unknown type" do
      info = DNSValidator.get_record_info("UNKNOWN")
      assert info == %{}
    end
  end
end
