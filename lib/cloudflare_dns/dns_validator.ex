defmodule CloudflareDns.DNSValidator do
  @moduledoc """
  Validation logic for DNS record operations.
  """

  alias CloudflareDns.CloudflareClient.DNSRecord

  @allowed_types ["A", "CNAME"]
  @forbidden_names ["www", "@", ""]

  @doc """
  Validates a DNS record for creation or update.
  """
  @spec validate_record(map()) :: {:ok, map()} | {:error, [String.t()]}
  def validate_record(attrs) do
    errors = []

    errors = validate_type(attrs, errors)
    errors = validate_name(attrs, errors)
    errors = validate_content(attrs, errors)

    case errors do
      [] -> {:ok, sanitize_attrs(attrs)}
      _ -> {:error, errors}
    end
  end

  @doc """
  Validates if a record can be edited or deleted based on its comment.
  """
  @spec can_modify_record?(DNSRecord.t()) :: boolean()
  def can_modify_record?(%DNSRecord{comment: comment}) do
    comment != "KEEP"
  end

  @doc """
  Validates if a record is student-created.
  """
  @spec student_record?(DNSRecord.t()) :: boolean()
  def student_record?(%DNSRecord{comment: comment}) do
    comment == "STUDENT"
  end

  @doc """
  Gets educational information for DNS record types.
  """
  @spec get_record_info(String.t()) :: map()
  def get_record_info("A") do
    %{
      type: "A",
      name: "Address Record",
      description: "Maps a domain name to an IPv4 address (like 192.168.1.1)",
      example_content: "192.0.2.1",
      use_case: "Use A records to point your subdomain to a server's IP address"
    }
  end

  def get_record_info("CNAME") do
    %{
      type: "CNAME",
      name: "Canonical Name Record",
      description: "Maps a domain name to another domain name (alias)",
      example_content: "example.com",
      use_case: "Use CNAME records to create an alias that points to another domain"
    }
  end

  def get_record_info(_), do: %{}

  @doc """
  Gets all allowed record types with their information.
  """
  @spec get_allowed_types() :: [map()]
  def get_allowed_types do
    Enum.map(@allowed_types, &get_record_info/1)
  end

  # Private validation functions

  defp zone_domain do
    Application.get_env(:cloudflare_dns, :cloudflare_domain)
  end

  defp validate_type(attrs, errors) do
    type = Map.get(attrs, "type") || Map.get(attrs, :type)

    cond do
      is_nil(type) or type == "" ->
        ["Record type is required" | errors]

      type not in @allowed_types ->
        ["Record type must be one of: #{Enum.join(@allowed_types, ", ")}" | errors]

      true ->
        errors
    end
  end

  defp validate_name(attrs, errors) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name) || ""
    normalized_name = String.trim(String.downcase(name))

    cond do
      normalized_name == "" ->
        ["Domain name is required" | errors]

      normalized_name in @forbidden_names ->
        ["Cannot create records for www, @ (root domain), or empty names" | errors]

      String.starts_with?(normalized_name, "*.") ->
        ["Wildcard domains are not allowed" | errors]

      String.contains?(normalized_name, " ") ->
        ["Domain names cannot contain spaces" | errors]

      not valid_subdomain_format?(normalized_name) ->
        ["Invalid subdomain format. Use only letters, numbers, and hyphens" | errors]

      true ->
        errors
    end
  end

  defp validate_content(attrs, errors) do
    content = Map.get(attrs, "content") || Map.get(attrs, :content) || ""
    type = Map.get(attrs, "type") || Map.get(attrs, :type)

    cond do
      String.trim(content) == "" ->
        ["Content is required" | errors]

      type == "A" and not valid_ipv4?(content) ->
        ["A records must contain a valid IPv4 address (e.g., 192.0.2.1)" | errors]

      type == "CNAME" and not valid_domain?(content) ->
        ["CNAME records must contain a valid domain name (e.g., example.com)" | errors]

      true ->
        errors
    end
  end

  defp valid_subdomain_format?(name) do
    # Remove the zone domain if present
    subdomain = String.replace_suffix(name, ".#{zone_domain()}", "")

    # Check if it's a valid subdomain format
    String.match?(subdomain, ~r/^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$/i)
  end

  defp valid_ipv4?(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, {_, _, _, _}} -> true
      _ -> false
    end
  end

  defp valid_domain?(domain) do
    # Basic domain validation - could be enhanced
    String.match?(domain, ~r/^[a-z0-9]([a-z0-9\-\.]*[a-z0-9])?$/i) and
      String.contains?(domain, ".") and
      not String.starts_with?(domain, ".") and
      not String.ends_with?(domain, ".")
  end

  defp sanitize_attrs(attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name, "")

    # Ensure name includes the zone domain if not already present
    full_name =
      if String.ends_with?(name, ".#{zone_domain()}") do
        name
      else
        "#{name}.#{zone_domain()}"
      end

    attrs
    |> Map.put("name", full_name)
    |> Map.put(:name, full_name)
  end
end
