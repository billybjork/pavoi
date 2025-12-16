defmodule Pavoi.TiktokLive.Connection do
  @moduledoc """
  WebSocket connection to Euler Stream's hosted TikTok Live service.

  Connects directly to `wss://ws.eulerstream.com` which handles all the
  complexity of TikTok's WebCast protocol. We just need to provide the
  TikTok username and our API key.

  This GenServer manages:
  - Establishing and maintaining the WebSocket connection
  - Receiving and parsing event messages
  - Broadcasting parsed events via PubSub
  - Handling disconnections and reconnection attempts

  ## Usage

      {:ok, pid} = Connection.start_link(unique_id: "pavoi", stream_id: 1)

  Events are broadcast to the `"tiktok_live:events"` PubSub topic with the format:
      {:tiktok_live_event, stream_id, event}

  """

  use WebSockex

  require Logger

  @euler_stream_ws_url "wss://ws.eulerstream.com"
  @reconnect_delay_ms 5_000
  @max_reconnect_attempts 5
  @heartbeat_interval_ms 30_000

  defmodule State do
    @moduledoc false
    defstruct [
      :unique_id,
      :stream_id,
      :websocket_url,
      :reconnect_attempts,
      :connected_at,
      :last_event_at,
      :heartbeat_ref
    ]
  end

  @doc """
  Starts the WebSocket connection process.

  ## Options

  - `:unique_id` - Required. TikTok username (without @) to connect to.
  - `:stream_id` - Required. Database ID of the stream record.
  - `:name` - Optional. Process name for registration.
  """
  def start_link(opts) do
    unique_id = Keyword.fetch!(opts, :unique_id)
    stream_id = Keyword.fetch!(opts, :stream_id)
    name = Keyword.get(opts, :name)

    api_key = euler_stream_api_key()

    if is_nil(api_key) or api_key == "" do
      Logger.error("Euler Stream API key not configured")
      {:error, :missing_api_key}
    else
      websocket_url = build_websocket_url(unique_id, api_key)

      Logger.info("Starting TikTok Live connection for @#{unique_id}, stream #{stream_id}")

      state = %State{
        unique_id: unique_id,
        stream_id: stream_id,
        websocket_url: websocket_url,
        reconnect_attempts: 0
      }

      ws_opts = [
        name: name,
        handle_initial_conn_failure: true
      ]

      WebSockex.start_link(websocket_url, __MODULE__, state, ws_opts)
    end
  end

  @doc """
  Stops the connection gracefully.
  """
  def stop(pid) do
    WebSockex.cast(pid, :stop)
  end

  # WebSockex callbacks

  @impl WebSockex
  def handle_connect(_conn, state) do
    Logger.info("Connected to Euler Stream for @#{state.unique_id}")

    # Start heartbeat timer
    heartbeat_ref = Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)

    new_state = %{
      state
      | connected_at: DateTime.utc_now(),
        reconnect_attempts: 0,
        heartbeat_ref: heartbeat_ref
    }

    # Broadcast connection event
    broadcast_event(state.stream_id, %{type: :connected, unique_id: state.unique_id})

    {:ok, new_state}
  end

  @impl WebSockex
  def handle_frame({:text, data}, state) do
    # Euler Stream sends JSON messages
    case Jason.decode(data) do
      {:ok, event_data} ->
        event = parse_euler_stream_event(event_data)

        if event do
          broadcast_event(state.stream_id, event)
        end

        {:ok, %{state | last_event_at: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.warning("Failed to parse JSON frame: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl WebSockex
  def handle_frame({:binary, data}, state) do
    # Euler Stream may also send binary protobuf frames
    alias Pavoi.TiktokLive.Proto.Parser

    case Parser.parse_push_frame(data) do
      {:ok, events} when is_list(events) ->
        Enum.each(events, fn event ->
          broadcast_event(state.stream_id, event)
        end)

        {:ok, %{state | last_event_at: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.debug("Failed to parse binary frame: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl WebSockex
  def handle_frame(frame, state) do
    Logger.debug("Received unknown frame type: #{inspect(frame)}")
    {:ok, state}
  end

  @impl WebSockex
  def handle_cast(:stop, state) do
    Logger.info("Stopping TikTok Live connection for @#{state.unique_id}")
    cancel_heartbeat(state.heartbeat_ref)
    {:close, state}
  end

  @impl WebSockex
  def handle_info(:heartbeat, state) do
    # Send a ping frame to keep connection alive
    heartbeat_ref = Process.send_after(self(), :heartbeat, @heartbeat_interval_ms)
    {:reply, {:ping, ""}, %{state | heartbeat_ref: heartbeat_ref}}
  end

  @impl WebSockex
  def handle_info(msg, state) do
    Logger.debug("Received unexpected message: #{inspect(msg)}")
    {:ok, state}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_map, state) do
    cancel_heartbeat(state.heartbeat_ref)

    reason = Map.get(disconnect_map, :reason)
    Logger.warning("Disconnected from Euler Stream: #{inspect(reason)}")

    # Broadcast disconnection event
    broadcast_event(state.stream_id, %{type: :disconnected, reason: reason})

    # Attempt reconnection if under max attempts
    if state.reconnect_attempts < @max_reconnect_attempts do
      Logger.info(
        "Attempting reconnection #{state.reconnect_attempts + 1}/#{@max_reconnect_attempts}"
      )

      Process.sleep(@reconnect_delay_ms)

      {:reconnect, state.websocket_url,
       %{state | reconnect_attempts: state.reconnect_attempts + 1}}
    else
      Logger.error("Max reconnection attempts reached for @#{state.unique_id}")
      broadcast_event(state.stream_id, %{type: :connection_failed, unique_id: state.unique_id})
      {:ok, state}
    end
  end

  @impl WebSockex
  def terminate(reason, state) do
    cancel_heartbeat(state.heartbeat_ref)
    Logger.info("TikTok Live connection terminated: #{inspect(reason)}")
    broadcast_event(state.stream_id, %{type: :terminated, reason: reason})
    :ok
  end

  # Private functions

  defp build_websocket_url(unique_id, api_key) do
    "#{@euler_stream_ws_url}?uniqueId=#{URI.encode(unique_id)}&apiKey=#{URI.encode(api_key)}"
  end

  defp euler_stream_api_key do
    Application.get_env(:pavoi, :euler_stream_api_key)
  end

  defp broadcast_event(stream_id, event) do
    Phoenix.PubSub.broadcast(
      Pavoi.PubSub,
      "tiktok_live:events",
      {:tiktok_live_event, stream_id, event}
    )
  end

  defp cancel_heartbeat(nil), do: :ok
  defp cancel_heartbeat(ref), do: Process.cancel_timer(ref)

  # Parse Euler Stream JSON events into our standard event format
  defp parse_euler_stream_event(%{"event" => "chat", "data" => data}) do
    %{
      type: :comment,
      user_id: get_in(data, ["user", "userId"]) |> to_string(),
      username: get_in(data, ["user", "uniqueId"]),
      nickname: get_in(data, ["user", "nickname"]),
      content: data["comment"],
      timestamp: parse_timestamp(data["createTime"]),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "gift", "data" => data}) do
    %{
      type: :gift,
      user_id: get_in(data, ["user", "userId"]) |> to_string(),
      username: get_in(data, ["user", "uniqueId"]),
      nickname: get_in(data, ["user", "nickname"]),
      gift_id: data["giftId"],
      gift_name: get_in(data, ["gift", "name"]),
      diamond_count: data["diamondCount"] || get_in(data, ["gift", "diamondCount"]),
      repeat_count: data["repeatCount"],
      repeat_end: data["repeatEnd"],
      timestamp: parse_timestamp(data["createTime"]),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "like", "data" => data}) do
    %{
      type: :like,
      user_id: get_in(data, ["user", "userId"]) |> to_string(),
      username: get_in(data, ["user", "uniqueId"]),
      nickname: get_in(data, ["user", "nickname"]),
      count: data["likeCount"] || data["count"],
      total_count: data["totalLikeCount"],
      timestamp: parse_timestamp(data["createTime"]),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "member", "data" => data}) do
    %{
      type: :join,
      user_id: get_in(data, ["user", "userId"]) |> to_string(),
      username: get_in(data, ["user", "uniqueId"]),
      nickname: get_in(data, ["user", "nickname"]),
      timestamp: parse_timestamp(data["createTime"]),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "roomUser", "data" => data}) do
    %{
      type: :viewer_count,
      viewer_count: data["viewerCount"],
      timestamp: DateTime.utc_now(),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "social", "data" => data}) do
    action_type =
      case data["displayType"] do
        "follow" -> :follow
        "share" -> :share
        _ -> :social
      end

    %{
      type: action_type,
      user_id: get_in(data, ["user", "userId"]) |> to_string(),
      username: get_in(data, ["user", "uniqueId"]),
      nickname: get_in(data, ["user", "nickname"]),
      timestamp: parse_timestamp(data["createTime"]),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "control", "data" => data}) do
    action = data["action"]

    type =
      case action do
        3 -> :stream_ended
        _ -> :control
      end

    %{
      type: type,
      action: action,
      timestamp: DateTime.utc_now(),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "roomInfo", "data" => data}) do
    %{
      type: :room_info,
      viewer_count: data["viewerCount"],
      like_count: data["likeCount"],
      title: data["title"],
      timestamp: DateTime.utc_now(),
      raw: data
    }
  end

  defp parse_euler_stream_event(%{"event" => "connected"}) do
    %{type: :euler_connected, timestamp: DateTime.utc_now()}
  end

  defp parse_euler_stream_event(%{"event" => "disconnected", "data" => data}) do
    %{type: :euler_disconnected, reason: data["reason"], timestamp: DateTime.utc_now()}
  end

  defp parse_euler_stream_event(%{"event" => event_type} = data) do
    Logger.debug("Unknown Euler Stream event type: #{event_type}")
    %{type: :unknown, event_type: event_type, raw: data, timestamp: DateTime.utc_now()}
  end

  defp parse_euler_stream_event(data) do
    Logger.debug("Unparseable Euler Stream message: #{inspect(data)}")
    nil
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(ts) when is_integer(ts) do
    # Euler Stream timestamps may be in seconds or milliseconds
    ts = if ts > 10_000_000_000, do: div(ts, 1000), else: ts

    case DateTime.from_unix(ts) do
      {:ok, dt} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()
end
