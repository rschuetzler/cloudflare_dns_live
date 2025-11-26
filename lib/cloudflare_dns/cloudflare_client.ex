defmodule CloudflareDns.CloudflareClient do
  @moduledoc """
  Client for interacting with the Cloudflare API.
  """
  require Logger

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
  @records_per_page 100

  def list_dns_records do
    zone_id = get_zone_id()
    token = get_token()

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case fetch_all_dns_records(zone_id, headers) do
      {:ok, record_pages} ->
        dns_records =
          record_pages
          |> Enum.reverse()
          |> Enum.concat()

        {:ok, dns_records}

      {:error, _reason} = error ->
        error
    end
  end

  defp fetch_all_dns_records(zone_id, headers, page \\ 1, acc \\ []) do
    url = "#{@base_url}/zones/#{zone_id}/dns_records"
    params = [page: page, per_page: @records_per_page]

    case Req.get(url, headers: headers, params: params) do
      {:ok, %{status: 200, body: %{"success" => true, "result" => records} = body}} ->
        mapped_records = Enum.map(records, &map_to_dns_record/1)
        new_acc = [mapped_records | acc]

        if has_more_pages?(body, page) do
          fetch_all_dns_records(zone_id, headers, page + 1, new_acc)
        else
          {:ok, new_acc}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp has_more_pages?(%{"result_info" => %{"total_pages" => total_pages}} = _body, page)
       when is_integer(total_pages) do
    page < total_pages
  end

  defp has_more_pages?(%{"result_info" => %{"count" => count, "per_page" => per_page}}, _page)
       when is_integer(count) and is_integer(per_page) do
    count == per_page
  end

  defp has_more_pages?(_body, _page), do: false

  @doc """
  Creates a new DNS record.
  """
  @spec create_dns_record(String.t(), String.t(), String.t(), map()) ::
          {:ok, DNSRecord.t()} | {:error, any()}
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
        dns_record = map_to_dns_record(record)
        Logger.info("DNS record created: type=#{type}, name=#{name}, content=#{content}")
        {:ok, dns_record}

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates an existing DNS record.
  """
  @spec update_dns_record(String.t(), String.t(), String.t(), String.t(), map()) ::
          {:ok, DNSRecord.t()} | {:error, any()}
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
        dns_record = map_to_dns_record(record)
        Logger.info("DNS record updated: id=#{record_id}, type=#{type}, name=#{name}, content=#{content}")
        {:ok, dns_record}

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Deletes a DNS record.

  ## Options
  - `:name` - The record name (for logging purposes)
  - `:type` - The record type (for logging purposes)
  """
  @spec delete_dns_record(String.t(), map()) :: :ok | {:error, any()}
  def delete_dns_record(record_id, opts \\ %{}) do
    zone_id = get_zone_id()
    token = get_token()

    url = "#{@base_url}/zones/#{zone_id}/dns_records/#{record_id}"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.delete(url, headers: headers) do
      {:ok, %{status: 200, body: %{"success" => true}}} ->
        log_message = build_delete_log_message(record_id, opts)
        Logger.info(log_message)
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "API request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  # Private functions

  defp build_delete_log_message(record_id, opts) do
    base = "DNS record deleted: id=#{record_id}"

    case {Map.get(opts, :name), Map.get(opts, :type)} do
      {nil, nil} -> base
      {name, nil} -> "#{base}, name=#{name}"
      {nil, type} -> "#{base}, type=#{type}"
      {name, type} -> "#{base}, type=#{type}, name=#{name}"
    end
  end

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
