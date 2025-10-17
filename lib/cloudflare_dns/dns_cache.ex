defmodule CloudflareDns.DNSCache do
  @moduledoc """
  ETS-based caching layer for DNS records with automatic refresh and PubSub broadcasting.
  """

  use GenServer
  alias CloudflareDns.CloudflareClient
  alias Phoenix.PubSub

  @table_name :dns_records_cache
  @refresh_interval :timer.minutes(2)
  @pubsub_topic "dns_records"

  defmodule CacheState do
    @moduledoc false
    defstruct [:table, :timer_ref, last_update: nil]
  end

  # Client API

  @doc """
  Starts the DNS cache GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Gets all DNS records from cache.
  """
  @spec get_all_records() :: [CloudflareClient.DNSRecord.t()]
  def get_all_records do
    case :ets.lookup(@table_name, :records) do
      [{:records, records}] -> records
      [] -> []
    end
  end

  @doc """
  Gets a specific DNS record by ID.
  """
  @spec get_record(String.t()) :: CloudflareClient.DNSRecord.t() | nil
  def get_record(id) do
    get_all_records()
    |> Enum.find(&(&1.id == id))
  end

  @doc """
  Gets filtered DNS records based on search criteria.
  """
  @spec search_records(String.t()) :: [CloudflareClient.DNSRecord.t()]
  def search_records(query) when is_binary(query) do
    normalized_query = String.downcase(String.trim(query))

    case normalized_query do
      "" ->
        get_all_records()

      _ ->
        get_all_records()
        |> Enum.filter(fn record ->
          String.contains?(String.downcase(record.name), normalized_query) or
            String.contains?(String.downcase(record.content), normalized_query) or
            String.contains?(String.downcase(record.type), normalized_query)
        end)
    end
  end

  @doc """
  Forces a refresh of the DNS records cache.
  """
  @spec refresh_cache() :: :ok
  def refresh_cache do
    GenServer.cast(__MODULE__, :refresh)
  end

  @doc """
  Invalidates and refreshes the cache after a DNS record change.
  """
  @spec invalidate_and_refresh() :: :ok
  def invalidate_and_refresh do
    GenServer.cast(__MODULE__, :invalidate_and_refresh)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :public, read_concurrency: true])

    # Defer initial load to allow the application to fully start
    # This prevents issues during build/release when env vars aren't available
    Process.send_after(self(), :initial_load, 100)

    # Schedule periodic refresh
    timer_ref = Process.send_after(self(), :refresh, @refresh_interval)

    {:ok, %CacheState{table: table, timer_ref: timer_ref, last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast(:refresh, state) do
    load_records(state.table)
    {:noreply, %{state | last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast(:invalidate_and_refresh, state) do
    # Clear cache and reload immediately
    :ets.delete_all_objects(state.table)
    load_records(state.table)

    # Broadcast update to all connected clients
    PubSub.broadcast(
      CloudflareDns.PubSub,
      @pubsub_topic,
      {:dns_records_updated, get_all_records()}
    )

    {:noreply, %{state | last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:initial_load, state) do
    load_records(state.table)
    {:noreply, %{state | last_update: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:refresh, state) do
    load_records(state.table)

    # Schedule next refresh
    timer_ref = Process.send_after(self(), :refresh, @refresh_interval)

    # Broadcast update to all connected clients
    PubSub.broadcast(
      CloudflareDns.PubSub,
      @pubsub_topic,
      {:dns_records_updated, get_all_records()}
    )

    {:noreply, %{state | timer_ref: timer_ref, last_update: DateTime.utc_now()}}
  end

  # Private functions

  defp load_records(table) do
    case CloudflareClient.list_dns_records() do
      {:ok, records} ->
        :ets.insert(table, {:records, records})

      {:error, reason} ->
        require Logger
        Logger.error("Failed to load DNS records: #{inspect(reason)}")
    end
  end

  @doc """
  Subscribe to DNS record updates for LiveView.
  """
  @spec subscribe() :: :ok
  def subscribe do
    PubSub.subscribe(CloudflareDns.PubSub, @pubsub_topic)
  end

  @doc """
  Get the PubSub topic for DNS records.
  """
  @spec pubsub_topic() :: String.t()
  def pubsub_topic, do: @pubsub_topic
end
