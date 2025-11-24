defmodule PavoiWeb.ShopifyOAuthController do
  use PavoiWeb, :controller
  require Logger

  def callback(conn, %{"code" => code} = params) do
    Logger.info("Shopify OAuth callback received!")
    Logger.info("Code: #{code}")
    Logger.info("All params: #{inspect(params)}")

    # Exchange code for access token
    case exchange_code_for_token(code) do
      {:ok, access_token} ->
        Logger.info("✅ SUCCESS! Got access token: #{access_token}")

        html(conn, """
        <html>
          <head><title>Shopify App Installed</title></head>
          <body style="font-family: sans-serif; padding: 40px; max-width: 600px; margin: 0 auto;">
            <h1 style="color: green;">✅ Success!</h1>
            <h2>Admin API Access Token:</h2>
            <pre style="background: #f5f5f5; padding: 20px; border-radius: 8px; overflow-x: auto;">#{access_token}</pre>
            <p><strong>⚠️ Copy this token immediately and add it to your .env and Railway!</strong></p>
            <p>Token format: <code>shpat_...</code></p>
            <hr/>
            <h3>Next steps:</h3>
            <ol>
              <li>Copy the token above</li>
              <li>Update .env: <code>SHOPIFY_ACCESS_TOKEN=#{access_token}</code></li>
              <li>Update Railway: <code>railway variables --set SHOPIFY_ACCESS_TOKEN=#{access_token}</code></li>
            </ol>
          </body>
        </html>
        """)

      {:error, reason} ->
        Logger.error("Failed to get access token: #{inspect(reason)}")

        html(conn, """
        <html>
          <body style="font-family: sans-serif; padding: 40px;">
            <h1 style="color: red;">❌ Error</h1>
            <p>Failed to exchange code for token:</p>
            <pre>#{inspect(reason)}</pre>
          </body>
        </html>
        """)
    end
  end

  defp exchange_code_for_token(code) do
    client_id = Application.get_env(:pavoi, :shopify_client_id)
    client_secret = Application.get_env(:pavoi, :shopify_client_secret)
    shop_name = Application.get_env(:pavoi, :shopify_store_name)

    url = "https://#{shop_name}.myshopify.com/admin/oauth/access_token"

    body = %{
      "client_id" => client_id,
      "client_secret" => client_secret,
      "code" => code
    }

    case Req.post(url, json: body) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
