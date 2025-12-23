# TikTok Shop Affiliate API Notes

## Discovery Date: 2024-12-23

## Current Status (Updated 2025-12-23)

### ✅ All Scopes Working!
Token reauthorized with new scopes. All affiliate APIs confirmed working.

### Working Endpoints
| Endpoint | Method | Status |
|----------|--------|--------|
| `/order/202309/orders/search` | POST | ✅ 473k+ orders |
| `/affiliate_seller/202406/marketplace_creators/search` | POST | ✅ Works! |
| `/affiliate_seller/202406/marketplace_creators/{creator_user_id}` | GET | ✅ Ready |
| `/affiliate_seller/202405/open_collaborations` | POST | ✅ Needs ProductId |
| `/affiliate_seller/202405/target_collaborations` | POST | ✅ Needs Name |

### Sample Results
- Creator search returns 12 creators per page
- High-GMV filter found creator with **$179,363 GMV**
- Keyword search works (e.g., "beauty" creators)

---

## Working Endpoints (Seller Account)

### Orders API
| Endpoint | Method | Status |
|----------|--------|--------|
| `/order/202309/orders/search` | POST | ✅ WORKS - 473k+ orders |

**Order Data Fields:**
- id, status, create_time, update_time
- buyer_email, user_id, buyer_message
- payment (currency, total_amount, discounts, tax, shipping)
- line_items (product_id, product_name, sku_id, seller_sku, sale_price)
- shipping (tracking_number, provider, delivery_time)
- Flags: is_sample_order, is_cod, is_affiliate

---

## Creator Marketplace API (seller.creator_marketplace.read)

### Search Creators on Marketplace
- **Path:** `/affiliate_seller/202406/marketplace_creators/search`
- **Method:** POST
- **page_size:** Must be 12 or 20

**Request Body:**
```json
{
  "keyword": "JefreeStar",
  "follower_demographics": {
    "age_ranges": ["AGE_RANGE_18_24", "AGE_RANGE_25_34"],
    "count_range": { "count_ge": 1000, "count_le": 10000 },
    "gender_distribution": { "gender": "MALE", "percentage_ge": 6000 }
  },
  "gmv_ranges": ["GMV_RANGE_0_100", "GMV_RANGE_100_1000"],
  "units_sold_ranges": ["UNITS_SOLD_RANGE_0_10", "UNITS_SOLD_RANGE_100_1000"]
}
```

**Response Data:**
- username, nickname, avatar
- selection_region, category_ids
- follower_count
- gmv, live_gmv, video_gmv (or gmv_range if no precise data permission)
- units_sold_range
- avg_ec_live_uv, avg_ec_video_view_count
- top_follower_demographics (age_ranges, major_gender)

**GMV Range Options:**
- GMV_RANGE_0_100
- GMV_RANGE_100_1000
- GMV_RANGE_1000_10000
- GMV_RANGE_10000_AND_ABOVE

**Units Sold Range Options:**
- UNITS_SOLD_RANGE_0_10
- UNITS_SOLD_RANGE_10_100
- UNITS_SOLD_RANGE_100_1000
- UNITS_SOLD_RANGE_1000_AND_ABOVE

**Age Range Options:**
- AGE_RANGE_18_24
- AGE_RANGE_25_34
- AGE_RANGE_35_44
- AGE_RANGE_45_54
- AGE_RANGE_55_AND_ABOVE

---

### Get Creator Performance
- **Path:** `/affiliate_seller/202406/marketplace_creators/{creator_user_id}`
- **Method:** GET

**Response Data:**
- username, nickname, avatar, bio_description
- selection_region, category_ids
- follower_count, profile_tt_uri
- top_collaborated_brand_ids, brand_collaboration_count
- units_sold (or units_sold_range)
- gmv, video_gmv, live_gmv (or gmv_range)
- gpm, video_gpm, live_gpm (GMV per mille)
- promoted_product_num
- ec_live_count, ec_video_count
- avg_ec_video_play_count
- avg_commission_rate (or avg_commission_rate_range)
- avg_gmv_per_buyer
- Engagement metrics: avg_ec_live_view_count, avg_ec_live_like_count, etc.
- category_gmv_distribution, content_gmv_distribution

**Rate Limits:**
- 10,000 requests per day quota

---

## Collaboration Management (seller.affiliate_collaboration.write)

### Create Open Collaboration
- **Path:** `/affiliate_seller/202405/open_collaborations`
- **Method:** POST
- **Required:** ProductId, commission_rate

### Create Target Collaboration
- **Path:** `/affiliate_seller/202405/target_collaborations`
- **Method:** POST
- **Required:** Name, (other fields TBD)

---

## Creator-Side Endpoints (Require Creator Auth)

These endpoints require a creator account to be authorized (not just seller):

| Endpoint | Error |
|----------|-------|
| `/affiliate_creator/202508/profiles` | "user type can not access" |
| `/affiliate_creator/202405/open_collaborations/products/search` | Needs creator auth |

---

## API Patterns Learned

1. **Path Structure:** `/{domain}_{user_type}/{version}/{resource}`
   - Examples: `/affiliate_seller/202406/...`, `/affiliate_creator/202405/...`

2. **Versions vary by endpoint:**
   - Marketplace creators: 202406
   - Open collaborations: 202405
   - Creator profiles: 202508
   - Orders: 202309

3. **Pagination:**
   - Uses `page_token` and `next_page_token`
   - page_size varies by endpoint (some require 12 or 20)

4. **Error Codes:**
   - 40006: "no schema found" = path doesn't exist
   - 36009004: Parameter validation error (path exists)
   - 36009002: Rate limit
   - 45101004: Daily quota exceeded (10k/day)
   - 105001: "user type can not access" = wrong auth type
