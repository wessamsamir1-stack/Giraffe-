-- =============================================================================
-- Giraffe — 02. الأنواع المعرّفة
-- =============================================================================

create type public.trust_level as enum (
  'new',        -- عضو جديد
  'verified',   -- موثّق: موبايل + صفقة واحدة
  'trusted',    -- موثوق: 5 صفقات + تقييم 4.0
  'elite'       -- مميز: 20 صفقة + تقييم 4.5 + رد سريع
);

create type public.item_condition as enum (
  'brand_new',
  'like_new',
  'good',
  'fair',
  'for_parts'
);

create type public.item_status as enum (
  'draft',        -- لسه بيترفع
  'pending',      -- في انتظار فحص المحتوى
  'available',
  'reserved',     -- عرض اتقبل — مقفول 48 ساعة
  'negotiating',
  'traded',
  'inactive',
  'rejected'      -- اترفض من الفحص
);

create type public.moderation_status as enum (
  'pending',
  'approved',
  'flagged',
  'rejected'
);

create type public.swipe_intent as enum (
  'skip',
  'interested',
  'dream'
);

create type public.trade_stage as enum (
  'negotiating',
  'offer_pending',
  'agreed',
  'meeting_set',
  'completed',
  'cancelled',
  'disputed'
);

create type public.offer_status as enum (
  'pending',
  'accepted',
  'declined',
  'countered',
  'expired'
);

create type public.message_kind as enum (
  'text',
  'image',
  'offer',
  'meeting',
  'system'
);

create type public.meeting_status as enum (
  'proposed',
  'confirmed',
  'completed',
  'no_show',
  'cancelled'
);

create type public.report_reason as enum (
  'inappropriate',
  'scam',
  'prohibited_item',
  'harassment',
  'fake_account',
  'other'
);

create type public.report_status as enum (
  'open',
  'reviewing',
  'actioned',
  'dismissed'
);

create type public.dispute_reason as enum (
  'not_as_described',
  'no_show',
  'damaged',
  'scam_attempt',
  'misconduct'
);

create type public.dispute_status as enum (
  'open',
  'reviewing',
  'resolved',
  'rejected'
);

create type public.notification_kind as enum (
  'match',
  'message',
  'offer',
  'wishlist',
  'nearby',
  'meeting',
  'review',
  'system'
);

create type public.security_event_kind as enum (
  'login_success',
  'login_failed',
  'new_device',
  'password_changed',
  'email_changed',
  'phone_changed',
  'two_factor_toggled',
  'account_deletion_requested',
  'data_exported'
);

create type public.place_kind as enum (
  'mall',
  'police_station',
  'cafe',
  'metro_station',
  'fuel_station',
  'public_square'
);
