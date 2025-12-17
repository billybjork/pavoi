defmodule Pavoi.TiktokLive.TestConnection do
  @moduledoc """
  Test module to verify TikTok Bridge connectivity.

  ## Testing the Bridge Service

  First, start the bridge service locally:

      cd services/tiktok-bridge
      npm install
      npm start

  Then test from IEx:

      iex> Pavoi.TiktokLive.TestConnection.test_bridge("charlidamelio")

  Or from command line:

      mix run -e 'Pavoi.TiktokLive.TestConnection.test_bridge("username")'

  ## Testing TikTok Room Info (no bridge needed)

      iex> Pavoi.TiktokLive.TestConnection.check_live("pavoi")
  """

  use WebSockex

  require Logger

  defmodule State do
    @moduledoc false
    defstruct [:parent, :event_count, :unique_id]
  end

  @doc """
  Check if a TikTok user is live by scraping their page.
  This doesn't require the bridge service.
  """
  def check_live(unique_id) do
    IO.puts("\n=== TikTok Live Status Check ===\n")
    IO.puts("Checking @#{unique_id}...")

    case Pavoi.TiktokLive.Client.fetch_room_info(unique_id) do
      {:ok, info} ->
        IO.puts("")
        IO.puts("  Room ID: #{info.room_id}")
        IO.puts("  Is Live: #{info.is_live}")
        IO.puts("  Title: #{info.title || "N/A"}")
        IO.puts("  Viewers: #{info.viewer_count}")
        IO.puts("")
        {:ok, info}

      {:error, reason} ->
        IO.puts("  Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test the TikTok Bridge service.

  Make sure the bridge is running first:
      cd services/tiktok-bridge && npm start

  ## Options

  - `bridge_url` - Bridge URL (default: from config or http://localhost:8080)
  - `timeout_seconds` - How long to wait for events (default: 30)
  """
  def test_bridge(unique_id, opts \\ []) do
    bridge_url = Keyword.get(opts, :bridge_url, bridge_url())
    timeout_seconds = Keyword.get(opts, :timeout_seconds, 30)

    IO.puts("\n=== TikTok Bridge Connection Test ===\n")
    IO.puts("Bridge URL: #{bridge_url}")
    IO.puts("Target: @#{unique_id}")
    IO.puts("Timeout: #{timeout_seconds}s\n")

    # Step 1: Check bridge health
    IO.puts("Step 1: Checking bridge health...")

    case Req.get("#{bridge_url}/health", receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        IO.puts("  Bridge is healthy: #{inspect(body)}\n")

      {:ok, %{status: status}} ->
        IO.puts("  ERROR: Bridge returned status #{status}")
        {:error, :bridge_unhealthy}

      {:error, reason} ->
        IO.puts("  ERROR: Could not reach bridge: #{inspect(reason)}")
        IO.puts("  Make sure the bridge is running: cd services/tiktok-bridge && npm start")
        {:error, :bridge_unreachable}
    end
    |> case do
      {:error, _} = error ->
        error

      _ ->
        # Step 2: Connect to bridge WebSocket
        IO.puts("Step 2: Connecting to bridge WebSocket...")

        ws_url = bridge_ws_url(bridge_url)
        state = %State{parent: self(), event_count: 0, unique_id: unique_id}

        case WebSockex.start_link(ws_url, __MODULE__, state) do
          {:ok, pid} ->
            IO.puts("  Connected to bridge!\n")

            # Step 3: Request connection to TikTok stream
            IO.puts("Step 3: Requesting connection to @#{unique_id}...")

            case Req.post("#{bridge_url}/connect",
                   json: %{uniqueId: unique_id},
                   receive_timeout: 30_000
                 ) do
              {:ok, %{status: 200, body: body}} ->
                IO.puts("  Success! Room ID: #{body["roomId"]}")
                IO.puts("  Waiting for events...\n")
                wait_for_events(pid, timeout_seconds * 1000, bridge_url, unique_id)

              {:ok, %{status: _, body: body}} ->
                IO.puts("  Failed: #{body["error"]}")
                WebSockex.cast(pid, :stop)
                {:error, body["error"]}

              {:error, reason} ->
                IO.puts("  Error: #{inspect(reason)}")
                WebSockex.cast(pid, :stop)
                {:error, reason}
            end

          {:error, reason} ->
            IO.puts("  ERROR: Failed to connect to WebSocket: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp wait_for_events(pid, timeout, bridge_url, unique_id) do
    receive do
      {:test_event, event_type, details} ->
        IO.puts("[#{event_type}] #{details}")
        wait_for_events(pid, timeout, bridge_url, unique_id)

      {:test_done, count} ->
        IO.puts("\n=== Test Complete ===")
        IO.puts("Received #{count} events")
        # Disconnect from stream
        Req.post("#{bridge_url}/disconnect", json: %{uniqueId: unique_id})
        :ok
    after
      timeout ->
        WebSockex.cast(pid, :stop)
        # Disconnect from stream
        Req.post("#{bridge_url}/disconnect", json: %{uniqueId: unique_id})
        IO.puts("\n=== Timeout reached ===")
        IO.puts("No more events received.")
        :ok
    end
  end

  # WebSockex callbacks

  @impl WebSockex
  def handle_connect(_conn, state) do
    send(state.parent, {:test_event, "CONNECTED", "WebSocket connection to bridge established"})
    {:ok, state}
  end

  @impl WebSockex
  def handle_frame({:text, data}, state) do
    case Jason.decode(data) do
      {:ok, %{"type" => type} = msg} ->
        {event_type, details} = format_event(type, msg)
        send(state.parent, {:test_event, event_type, details})
        {:ok, %{state | event_count: state.event_count + 1}}

      {:ok, msg} ->
        send(state.parent, {:test_event, "JSON", inspect(msg, limit: 100)})
        {:ok, %{state | event_count: state.event_count + 1}}

      {:error, _} ->
        send(state.parent, {:test_event, "PARSE_ERROR", "Failed to parse JSON"})
        {:ok, state}
    end
  end

  @impl WebSockex
  def handle_frame(frame, state) do
    send(state.parent, {:test_event, "FRAME", inspect(frame)})
    {:ok, state}
  end

  @impl WebSockex
  def handle_cast(:stop, state) do
    send(state.parent, {:test_done, state.event_count})
    {:close, state}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_map, state) do
    reason = Map.get(disconnect_map, :reason, "unknown")
    send(state.parent, {:test_event, "DISCONNECTED", inspect(reason)})
    send(state.parent, {:test_done, state.event_count})
    {:ok, state}
  end

  @impl WebSockex
  def terminate(_reason, state) do
    send(state.parent, {:test_done, state.event_count})
    :ok
  end

  # Event formatters

  defp format_event("status", msg) do
    connections = msg["connections"] || []
    {"STATUS", "Active connections: #{inspect(connections)}"}
  end

  defp format_event("connected", msg) do
    room_id = msg["roomId"] || "?"
    {"CONNECTED", "Stream connected, Room ID: #{room_id}"}
  end

  defp format_event("disconnected", _msg) do
    {"DISCONNECTED", "Stream disconnected"}
  end

  defp format_event("error", msg) do
    error = msg["error"] || "unknown"
    {"ERROR", error}
  end

  defp format_event("chat", msg) do
    data = msg["data"] || %{}
    user = data["uniqueId"] || "?"
    comment = data["comment"] || ""
    {"CHAT", "@#{user}: #{String.slice(comment, 0, 60)}"}
  end

  defp format_event("gift", msg) do
    data = msg["data"] || %{}
    user = data["uniqueId"] || "?"
    gift = data["giftName"] || "gift"
    diamonds = data["diamondCount"] || 0
    {"GIFT", "@#{user} sent #{gift} (#{diamonds} diamonds)"}
  end

  defp format_event("like", msg) do
    data = msg["data"] || %{}
    user = data["uniqueId"] || "?"
    count = data["likeCount"] || 1
    total = data["totalLikeCount"]
    total_str = if total, do: " (total: #{total})", else: ""
    {"LIKE", "@#{user} x#{count}#{total_str}"}
  end

  defp format_event("member", msg) do
    data = msg["data"] || %{}
    user = data["uniqueId"] || "?"
    {"JOIN", "@#{user} joined the stream"}
  end

  defp format_event("roomUser", msg) do
    data = msg["data"] || %{}
    viewers = data["viewerCount"] || 0
    {"VIEWERS", "#{viewers} watching"}
  end

  defp format_event("social", msg) do
    data = msg["data"] || %{}
    user = data["uniqueId"] || "?"
    action = data["displayType"] || "social"
    {"SOCIAL", "@#{user} #{action}"}
  end

  defp format_event("streamEnd", _msg) do
    {"STREAM_END", "Stream has ended"}
  end

  defp format_event(event_type, _msg) do
    {"EVENT", event_type}
  end

  defp bridge_url do
    Application.get_env(:pavoi, :tiktok_bridge_url, "http://localhost:8080")
  end

  defp bridge_ws_url(http_url) do
    http_url
    |> String.replace(~r{^http://}, "ws://")
    |> String.replace(~r{^https://}, "wss://")
    |> Kernel.<>("/events")
  end
end
