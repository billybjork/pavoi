defmodule Pavoi.TiktokLiveFixtures do
  @moduledoc """
  Test helpers for creating TikTok Live stream data.

  These fixtures create realistic stream data for testing stream reports,
  lifecycle transitions, and other TikTok Live functionality.
  """

  alias Pavoi.Catalog
  alias Pavoi.Repo
  alias Pavoi.TiktokLive.{Comment, Stream}

  @doc """
  Creates a brand for testing. Returns existing brand if slug already exists.
  """
  def brand_fixture(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])
    slug = attrs[:slug] || "test-brand-#{unique_id}"

    case Catalog.get_brand_by_slug(slug) do
      nil ->
        {:ok, brand} =
          Catalog.create_brand(%{
            name: attrs[:name] || "Test Brand #{unique_id}",
            slug: slug
          })

        brand

      brand ->
        brand
    end
  end

  @doc """
  Creates a stream with sensible defaults.

  ## Options

  - `:brand` - Use this brand (creates one if not provided)
  - `:brand_id` - Use this brand_id directly
  - `:status` - Stream status (:capturing, :ended, :failed). Default: :ended
  - `:duration_minutes` - How long the stream lasted. Default: 60
  - `:started_at` - When the stream started. Default: duration_minutes ago
  - `:ended_at` - When the stream ended. Default: now (only if status is :ended)
  - `:viewer_count_peak` - Peak viewers. Default: 100
  - `:total_likes` - Total likes. Default: 1000
  - `:total_comments` - Total comments count. Default: 50
  - `:total_follows` - Total follows. Default: 10
  - `:total_shares` - Total shares. Default: 5
  - `:report_sent_at` - When report was sent. Default: nil
  - `:unique_id` - TikTok username. Default: "testuser"
  - `:room_id` - TikTok room ID. Default: random

  ## Examples

      # A completed stream that ran for 2 hours
      stream_fixture(duration_minutes: 120, status: :ended)

      # A stream currently capturing
      stream_fixture(status: :capturing)

      # A stream where report was already sent
      stream_fixture(report_sent_at: DateTime.utc_now())
  """
  def stream_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})
    brand = attrs[:brand] || brand_fixture()
    brand_id = attrs[:brand_id] || brand.id
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      duration_minutes: 60,
      status: :ended,
      room_id: "#{System.unique_integer([:positive])}",
      unique_id: "testuser",
      title: "Test Stream",
      viewer_count_peak: 100,
      total_likes: 1000,
      total_comments: 50,
      total_gifts_value: 500,
      total_follows: 10,
      total_shares: 5,
      report_sent_at: nil
    }

    merged = Map.merge(defaults, attrs)
    started_at = merged[:started_at] || DateTime.add(now, -merged.duration_minutes, :minute)
    ended_at = stream_ended_at(merged.status, merged[:ended_at], now)

    stream_attrs =
      Map.take(merged, [
        :room_id,
        :unique_id,
        :title,
        :status,
        :viewer_count_peak,
        :total_likes,
        :total_comments,
        :total_gifts_value,
        :total_follows,
        :total_shares,
        :report_sent_at
      ])
      |> Map.merge(%{started_at: started_at, ended_at: ended_at})

    {:ok, stream} =
      %Stream{brand_id: brand_id}
      |> Stream.changeset(stream_attrs)
      |> Repo.insert()

    stream
  end

  defp stream_ended_at(:ended, nil, now), do: now
  defp stream_ended_at(:ended, ended_at, _now), do: ended_at
  defp stream_ended_at(_status, _ended_at, _now), do: nil

  @doc """
  Creates a stream that looks like a "false start" - very short with minimal engagement.
  These should NOT generate reports.
  """
  def false_start_stream_fixture(attrs \\ %{}) do
    attrs
    |> Map.put_new(:duration_minutes, 1)
    |> Map.put_new(:total_comments, 3)
    |> Map.put_new(:total_likes, 10)
    |> stream_fixture()
  end

  @doc """
  Creates a stream in an inconsistent state - ended but with nil ended_at.
  This is a bug state that can occur due to race conditions.
  """
  def inconsistent_stream_fixture(attrs \\ %{}) do
    brand = attrs[:brand] || brand_fixture()

    naive_now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    utc_now = DateTime.utc_now() |> DateTime.truncate(:second)
    started_at = attrs[:started_at] || DateTime.add(utc_now, -60, :minute)

    # Insert directly to bypass changeset validation
    stream_attrs = %{
      brand_id: brand.id,
      room_id: attrs[:room_id] || "#{System.unique_integer([:positive])}",
      unique_id: attrs[:unique_id] || "testuser",
      started_at: started_at,
      ended_at: nil,
      status: :ended,
      viewer_count_peak: 100,
      total_likes: 1000,
      total_comments: 50
    }

    {1, [stream]} =
      Repo.insert_all(
        Stream,
        [
          stream_attrs
          |> Map.put(:inserted_at, naive_now)
          |> Map.put(:updated_at, naive_now)
        ],
        returning: true
      )

    stream
  end

  @doc """
  Creates a comment for a stream.

  ## Options

  - `:stream` - The stream to add the comment to (required or :stream_id)
  - `:stream_id` - The stream ID directly
  - `:brand_id` - The brand ID (uses stream's brand_id if not provided)
  - `:text` - Comment text. Default: "Great stream!"
  - `:username` - TikTok username. Default: "viewer123"
  - `:commented_at` - When comment was made. Default: now
  - `:sentiment` - Classification sentiment. Default: nil
  - `:category` - Classification category. Default: nil
  """
  def comment_fixture(attrs) do
    attrs = Enum.into(attrs, %{})
    {stream_id, brand_id} = resolve_stream_and_brand(attrs)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      user_id: "user_#{System.unique_integer([:positive])}",
      username: "viewer#{System.unique_integer([:positive])}",
      nickname: nil,
      text: "Great stream!",
      commented_at: now
    }

    merged = Map.merge(defaults, attrs)

    comment_attrs = %{
      stream_id: stream_id,
      tiktok_user_id: merged.user_id,
      tiktok_username: merged.username,
      tiktok_nickname: merged.nickname || merged.username || "Viewer",
      comment_text: merged.text,
      commented_at: merged.commented_at,
      raw_event: %{}
    }

    {:ok, comment} =
      %Comment{brand_id: brand_id}
      |> Comment.changeset(comment_attrs)
      |> Repo.insert()

    maybe_classify_comment(comment, merged[:sentiment], merged[:category], now)
  end

  defp resolve_stream_and_brand(%{stream: stream}) when not is_nil(stream) do
    {stream.id, stream.brand_id}
  end

  defp resolve_stream_and_brand(%{stream_id: stream_id, brand_id: brand_id})
       when not is_nil(stream_id) and not is_nil(brand_id) do
    {stream_id, brand_id}
  end

  defp resolve_stream_and_brand(_attrs) do
    raise ArgumentError, "comment_fixture requires :stream or both :stream_id and :brand_id"
  end

  defp maybe_classify_comment(comment, nil, nil, _now), do: comment

  defp maybe_classify_comment(comment, sentiment, category, now) do
    {:ok, comment} =
      comment
      |> Ecto.Changeset.change(%{
        sentiment: sentiment,
        category: category,
        classified_at: now
      })
      |> Repo.update()

    comment
  end

  @doc """
  Creates multiple comments for a stream.
  Useful for testing comment aggregation and flash sale detection.

  ## Options

  - `:stream` - The stream (required)
  - `:count` - Number of comments to create. Default: 10
  - `:texts` - List of comment texts (cycles if fewer than count)
  - `:flash_sale_text` - If provided, creates this exact text `count` times (for flash sale testing)
  """
  def comments_fixture(attrs) do
    stream = attrs[:stream] || raise ArgumentError, "comments_fixture requires :stream"
    count = attrs[:count] || 10

    texts =
      cond do
        attrs[:flash_sale_text] ->
          List.duplicate(attrs[:flash_sale_text], count)

        attrs[:texts] ->
          Elixir.Stream.cycle(attrs[:texts]) |> Enum.take(count)

        true ->
          Enum.map(1..count, fn i -> "Comment #{i}" end)
      end

    Enum.map(texts, fn text ->
      comment_fixture(stream: stream, text: text)
    end)
  end

  @doc """
  Creates a realistic stream with comments for testing reports.

  Returns `{stream, comments}` tuple.

  ## Options

  All stream_fixture options plus:
  - `:comment_count` - Number of comments to create. Default: 20
  - `:flash_sale_count` - Number of flash sale comments. Default: 0
  - `:flash_sale_text` - Text for flash sale comments. Default: "123"
  """
  def stream_with_comments_fixture(attrs \\ %{}) do
    stream = stream_fixture(attrs)

    regular_count = (attrs[:comment_count] || 20) - (attrs[:flash_sale_count] || 0)

    regular_comments =
      if regular_count > 0 do
        comments_fixture(stream: stream, count: regular_count)
      else
        []
      end

    flash_sale_comments =
      if (attrs[:flash_sale_count] || 0) > 0 do
        comments_fixture(
          stream: stream,
          count: attrs[:flash_sale_count],
          flash_sale_text: attrs[:flash_sale_text] || "123"
        )
      else
        []
      end

    {stream, regular_comments ++ flash_sale_comments}
  end

  @doc """
  Marks a stream as ended with the given ended_at time.
  Useful for testing timing-related behavior.
  """
  def end_stream(stream, ended_at \\ nil) do
    ended_at = ended_at || DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, stream} =
      stream
      |> Ecto.Changeset.change(%{status: :ended, ended_at: ended_at})
      |> Repo.update()

    stream
  end

  @doc """
  Marks a stream's report as sent.
  """
  def mark_report_sent(stream, sent_at \\ nil) do
    sent_at = sent_at || DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, stream} =
      stream
      |> Ecto.Changeset.change(%{report_sent_at: sent_at})
      |> Repo.update()

    stream
  end

  @doc """
  Recovers a stream (sets status to capturing, clears ended_at).
  Simulates what the stream reconciler does.
  """
  def recover_stream(stream) do
    {:ok, stream} =
      stream
      |> Ecto.Changeset.change(%{status: :capturing, ended_at: nil})
      |> Repo.update()

    stream
  end
end
