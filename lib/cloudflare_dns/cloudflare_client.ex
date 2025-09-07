defmodule CloudflareDns.CloudflareClient do
  @moduledoc """
  Client for interacting with the Cloudflare API.
  """

  @base_url "https://api.cloudflare.com/client/v4"

  defmodule DNSRecord do
    @moduledoc """
    Represents a Cloudflare DNS record.
    """
    
    defstruct [
      :id,
      :type,
      :name,
      :content,
      :ttl,
      :proxied,
      :zone_id,
      :zone_name,
      :comment,
      :created_on,
      :modified_on
    ]

    @type t :: %__MODULE__{
      id: String.t(),
      type: String.t(),
      name: String.t(),
      content: String.t(),
      ttl: integer(),
      proxied: boolean(),
      zone_id: String.t(),
      zone_name: String.t(),
      comment: String.t() | nil,
      created_on: String.t(),
      modified_on: String.t()
    }
  end

  @doc """
  Lists all DNS records for the configured zone.
  """
  @spec list_dns_records() :: {:ok, [DNSRecord.t()]} | {:error, any()}
  def list_dns_records do
    zone_id = get_zone_id()
    token = get_token()

    url = "#{@base_url}/zones/#{zone_id}/dns_records"
    
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"success" => true, "result" => records}}} ->
        dns_records = Enum.map(records, &map_to_dns_record/1)
        {:ok, dns_records}

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Creates a new DNS record.
  """
  @spec create_dns_record(String.t(), String.t(), String.t(), map()) :: {:ok, DNSRecord.t()} | {:error, any()}
  def create_dns_record(type, name, content, opts \\ %{}) do
    zone_id = get_zone_id()
    token = get_token()

    url = "#{@base_url}/zones/#{zone_id}/dns_records"
    
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      type: type,
      name: name,
      content: content,
      ttl: Map.get(opts, :ttl, 1),
      comment: Map.get(opts, :comment, "STUDENT")
    }

    case Req.post(url, headers: headers, json: body) do
      {:ok, %{status: 200, body: %{"success" => true, "result" => record}}} ->
        {:ok, map_to_dns_record(record)}

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates an existing DNS record.
  """
  @spec update_dns_record(String.t(), String.t(), String.t(), String.t(), map()) :: {:ok, DNSRecord.t()} | {:error, any()}
  def update_dns_record(record_id, type, name, content, opts \\ %{}) do
    zone_id = get_zone_id()
    token = get_token()

    url = "#{@base_url}/zones/#{zone_id}/dns_records/#{record_id}"
    
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      type: type,
      name: name,
      content: content,
      ttl: Map.get(opts, :ttl, 1),
      comment: Map.get(opts, :comment)
    }

    case Req.patch(url, headers: headers, json: body) do
      {:ok, %{status: 200, body: %{"success" => true, "result" => record}}} ->
        {:ok, map_to_dns_record(record)}

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Deletes a DNS record.
  """
  @spec delete_dns_record(String.t()) :: :ok | {:error, any()}
  def delete_dns_record(record_id) do
    zone_id = get_zone_id()
    token = get_token()

    url = "#{@base_url}/zones/#{zone_id}/dns_records/#{record_id}"
    
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.delete(url, headers: headers) do
      {:ok, %{status: 200, body: %{"success" => true}}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp get_token do
    System.get_env("CLOUDFLARE_TOKEN") || raise "CLOUDFLARE_TOKEN environment variable not set"
  end

  defp get_zone_id do
    System.get_env("CLOUDFLARE_ZONE") || raise "CLOUDFLARE_ZONE environment variable not set"
  end

  defp map_to_dns_record(record) do
    %DNSRecord{
      id: record["id"],
      type: record["type"],
      name: record["name"],
      content: record["content"],
      ttl: record["ttl"],
      proxied: record["proxied"],
      zone_id: record["zone_id"],
      zone_name: record["zone_name"],
      comment: record["comment"],
      created_on: record["created_on"],
      modified_on: record["modified_on"]
    }
  end
end