defmodule Pavoi.TiktokLive.Proto.Webcast do
  @moduledoc """
  Protobuf message definitions for TikTok's WebCast service.

  These definitions are reverse-engineered from TikTok's live streaming protocol.
  The WebCast service sends binary protobuf messages over WebSocket containing
  various event types (comments, gifts, likes, viewer counts, etc.).

  Note: Field numbers and structures are based on analysis of the TikTokLive
  Python library's proto definitions. They may need adjustment if TikTok
  changes their protocol.
  """

  use Protobuf, syntax: :proto3

  # Common structures

  defmodule User do
    @moduledoc "TikTok user information included in events"
    use Protobuf, syntax: :proto3

    field :id, 1, type: :uint64
    field :short_id, 2, type: :uint64
    field :nickname, 3, type: :string
    field :avatar_thumb, 4, type: Pavoi.TiktokLive.Proto.Webcast.Image
    field :avatar_medium, 5, type: Pavoi.TiktokLive.Proto.Webcast.Image
    field :avatar_large, 6, type: Pavoi.TiktokLive.Proto.Webcast.Image
    field :verified, 7, type: :bool
    field :sec_uid, 9, type: :string
    field :unique_id, 38, type: :string
    field :bio_description, 5001, type: :string
    field :display_id, 46, type: :string
  end

  defmodule Image do
    @moduledoc "Image URL structure"
    use Protobuf, syntax: :proto3

    field :url_list, 1, repeated: true, type: :string
    field :uri, 2, type: :string
    field :width, 3, type: :uint64
    field :height, 4, type: :uint64
  end

  defmodule Gift do
    @moduledoc "Gift information"
    use Protobuf, syntax: :proto3

    field :id, 1, type: :uint64
    field :name, 2, type: :string
    field :diamond_count, 5, type: :uint32
    field :image, 7, type: Pavoi.TiktokLive.Proto.Webcast.Image
    field :describe, 9, type: :string
  end

  # Main response wrapper

  defmodule WebcastResponse do
    @moduledoc """
    Top-level response wrapper containing all WebCast messages.

    The WebSocket receives these responses containing one or more messages
    of various types (chat, gift, like, etc.).
    """
    use Protobuf, syntax: :proto3

    field :messages, 1, repeated: true, type: Pavoi.TiktokLive.Proto.Webcast.Message
    field :cursor, 2, type: :string
    field :fetch_interval, 3, type: :uint64
    field :now, 4, type: :uint64
    field :internal_ext, 5, type: :string
    field :fetch_type, 6, type: :uint32
    # route_params is a map<string, string> but protobuf-elixir doesn't support it directly
    # We'll skip it for now as it's not essential
    field :heartbeat_duration, 8, type: :uint64
    field :needs_ack, 9, type: :bool
    field :push_server, 10, type: :string
    field :live_cursor, 11, type: :string
    field :history_comment_cursor, 12, type: :string
  end

  defmodule Message do
    @moduledoc "Generic message container with type and payload"
    use Protobuf, syntax: :proto3

    field :type, 1, type: :string
    field :payload, 2, type: :bytes
  end

  # Event-specific messages

  defmodule WebcastChatMessage do
    @moduledoc "Chat/comment message from a viewer"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :user, 2, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :content, 3, type: :string
    field :visible_to_sender, 4, type: :bool
    field :content_language, 6, type: :string
  end

  defmodule WebcastGiftMessage do
    @moduledoc "Gift sent by a viewer"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :gift_id, 2, type: :uint64
    field :fan_ticket_count, 4, type: :uint64
    field :group_count, 5, type: :uint32
    field :repeat_count, 6, type: :uint32
    field :combo_count, 7, type: :uint32
    field :user, 8, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :to_user, 9, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :repeat_end, 10, type: :uint32
    field :gift, 15, type: Pavoi.TiktokLive.Proto.Webcast.Gift
    field :diamond_count, 16, type: :uint64
  end

  defmodule WebcastLikeMessage do
    @moduledoc "Like event from a viewer"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :count, 2, type: :uint64
    field :total_count, 3, type: :uint64
    field :user, 5, type: Pavoi.TiktokLive.Proto.Webcast.User
  end

  defmodule WebcastMemberMessage do
    @moduledoc "User join event"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :user, 2, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :member_count, 3, type: :uint64
    field :action, 10, type: :uint32
  end

  defmodule WebcastRoomUserSeqMessage do
    @moduledoc "Viewer count update"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :ranks, 2, repeated: true, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :total_user, 3, type: :uint64
    field :user, 4, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :viewer_count, 5, type: :uint64
  end

  defmodule WebcastSocialMessage do
    @moduledoc "Social action (follow, share, etc.)"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :user, 2, type: Pavoi.TiktokLive.Proto.Webcast.User
    field :share_type, 3, type: :uint64
    field :action, 4, type: :uint64
    field :share_target, 5, type: :string
    field :follow_count, 6, type: :uint64
  end

  defmodule WebcastControlMessage do
    @moduledoc "Stream control message (pause, end, etc.)"
    use Protobuf, syntax: :proto3

    field :common, 1, type: Pavoi.TiktokLive.Proto.Webcast.Common
    field :action, 2, type: :int32
  end

  defmodule Common do
    @moduledoc "Common fields present in most messages"
    use Protobuf, syntax: :proto3

    field :method, 1, type: :string
    field :msg_id, 2, type: :uint64
    field :room_id, 3, type: :uint64
    field :create_time, 4, type: :uint64
    field :monitor, 5, type: :uint32
    field :is_show_msg, 6, type: :bool
    field :describe, 7, type: :string
    field :display_text, 8, type: Pavoi.TiktokLive.Proto.Webcast.Text
  end

  defmodule Text do
    @moduledoc "Formatted text with color and key"
    use Protobuf, syntax: :proto3

    field :key, 1, type: :string
    field :default_pattern, 2, type: :string
    field :default_format, 3, type: Pavoi.TiktokLive.Proto.Webcast.TextFormat
  end

  defmodule TextFormat do
    @moduledoc "Text formatting information"
    use Protobuf, syntax: :proto3

    field :color, 1, type: :string
    field :bold, 2, type: :bool
    field :italic, 3, type: :bool
    field :weight, 4, type: :uint32
  end

  # Ack message (sent back to server)

  defmodule WebcastPushFrame do
    @moduledoc "Frame wrapper for WebSocket messages"
    use Protobuf, syntax: :proto3

    field :seq_id, 1, type: :uint64
    field :log_id, 2, type: :uint64
    field :service, 3, type: :uint64
    field :method, 4, type: :uint64
    field :headers, 5, repeated: true, type: Pavoi.TiktokLive.Proto.Webcast.Header
    field :payload_encoding, 6, type: :string
    field :payload_type, 7, type: :string
    field :payload, 8, type: :bytes
  end

  defmodule Header do
    @moduledoc "Header key-value pair"
    use Protobuf, syntax: :proto3

    field :key, 1, type: :string
    field :value, 2, type: :string
  end
end
