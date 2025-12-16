defmodule Pavoi.TiktokLive.Proto.Parser do
  @moduledoc """
  Parses TikTok WebCast protobuf messages into structured Elixir data.

  This module handles decoding the binary protobuf data received from
  TikTok's WebSocket and converting it into normalized event maps.
  """

  require Logger

  alias Pavoi.TiktokLive.Proto.Webcast

  @doc """
  Parses a WebCast response from binary protobuf data.

  Returns a list of parsed events, each with a `:type` and event-specific data.
  """
  def parse_response(binary_data) when is_binary(binary_data) do
    try do
      case Webcast.WebcastResponse.decode(binary_data) do
        %Webcast.WebcastResponse{messages: messages} when is_list(messages) ->
          events =
            messages
            |> Enum.map(&parse_message/1)
            |> Enum.reject(&is_nil/1)

          {:ok, events}

        _ ->
          {:error, :invalid_response}
      end
    rescue
      e ->
        Logger.warning("Failed to decode WebCast response: #{inspect(e)}")
        {:error, {:decode_error, e}}
    end
  end

  @doc """
  Parses a WebcastPushFrame (the outer wrapper for WebSocket messages).
  """
  def parse_push_frame(binary_data) when is_binary(binary_data) do
    try do
      frame = Webcast.WebcastPushFrame.decode(binary_data)
      parse_response(frame.payload)
    rescue
      _e ->
        # Try parsing as direct response if frame parsing fails
        parse_response(binary_data)
    end
  end

  # Message type handlers

  defp parse_message(%Webcast.Message{type: "WebcastChatMessage", payload: payload}) do
    try do
      chat = Webcast.WebcastChatMessage.decode(payload)

      %{
        type: :comment,
        user_id: user_id(chat.user),
        username: username(chat.user),
        nickname: nickname(chat.user),
        content: chat.content,
        timestamp: timestamp(chat.common),
        raw: chat
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastGiftMessage", payload: payload}) do
    try do
      gift_msg = Webcast.WebcastGiftMessage.decode(payload)

      %{
        type: :gift,
        user_id: user_id(gift_msg.user),
        username: username(gift_msg.user),
        nickname: nickname(gift_msg.user),
        gift_id: gift_msg.gift_id,
        gift_name: gift_name(gift_msg.gift),
        diamond_count: gift_msg.diamond_count,
        repeat_count: gift_msg.repeat_count,
        combo_count: gift_msg.combo_count,
        timestamp: timestamp(gift_msg.common),
        raw: gift_msg
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastLikeMessage", payload: payload}) do
    try do
      like = Webcast.WebcastLikeMessage.decode(payload)

      %{
        type: :like,
        user_id: user_id(like.user),
        username: username(like.user),
        nickname: nickname(like.user),
        count: like.count,
        total_count: like.total_count,
        timestamp: timestamp(like.common),
        raw: like
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastMemberMessage", payload: payload}) do
    try do
      member = Webcast.WebcastMemberMessage.decode(payload)

      %{
        type: :join,
        user_id: user_id(member.user),
        username: username(member.user),
        nickname: nickname(member.user),
        member_count: member.member_count,
        action: member.action,
        timestamp: timestamp(member.common),
        raw: member
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastRoomUserSeqMessage", payload: payload}) do
    try do
      seq = Webcast.WebcastRoomUserSeqMessage.decode(payload)

      %{
        type: :viewer_count,
        viewer_count: seq.viewer_count || seq.total_user,
        timestamp: timestamp(seq.common),
        raw: seq
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastSocialMessage", payload: payload}) do
    try do
      social = Webcast.WebcastSocialMessage.decode(payload)

      action_type =
        case social.action do
          1 -> :follow
          _ -> :share
        end

      %{
        type: action_type,
        user_id: user_id(social.user),
        username: username(social.user),
        nickname: nickname(social.user),
        follow_count: social.follow_count,
        timestamp: timestamp(social.common),
        raw: social
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: "WebcastControlMessage", payload: payload}) do
    try do
      control = Webcast.WebcastControlMessage.decode(payload)

      action_type =
        case control.action do
          3 -> :stream_ended
          _ -> :control
        end

      %{
        type: action_type,
        action: control.action,
        timestamp: timestamp(control.common),
        raw: control
      }
    rescue
      _ -> nil
    end
  end

  defp parse_message(%Webcast.Message{type: type, payload: _payload}) do
    # Log unknown message types for debugging
    Logger.debug("Unknown WebCast message type: #{type}")
    nil
  end

  defp parse_message(_), do: nil

  # Helper functions

  defp user_id(nil), do: nil
  defp user_id(%{id: id}), do: to_string(id)

  defp username(nil), do: nil

  defp username(%{unique_id: unique_id}) when is_binary(unique_id) and unique_id != "",
    do: unique_id

  defp username(%{display_id: display_id}) when is_binary(display_id) and display_id != "",
    do: display_id

  defp username(_), do: nil

  defp nickname(nil), do: nil
  defp nickname(%{nickname: nickname}), do: nickname

  defp gift_name(nil), do: nil
  defp gift_name(%{name: name}), do: name

  defp timestamp(nil), do: DateTime.utc_now()

  defp timestamp(%{create_time: create_time}) when is_integer(create_time) and create_time > 0 do
    # TikTok timestamps are in milliseconds
    case DateTime.from_unix(create_time, :millisecond) do
      {:ok, dt} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp timestamp(_), do: DateTime.utc_now()
end
