-- ====================================
-- TruckNav Pro - Supabase Database Schema
-- ====================================
-- Run this SQL in your Supabase SQL Editor to create all tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================
-- 1. User Profiles Table
-- ====================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ====================================
-- 2. Saved Routes Table
-- ====================================
CREATE TABLE saved_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_latitude DOUBLE PRECISION NOT NULL,
    start_longitude DOUBLE PRECISION NOT NULL,
    end_latitude DOUBLE PRECISION NOT NULL,
    end_longitude DOUBLE PRECISION NOT NULL,
    distance DOUBLE PRECISION NOT NULL,
    duration DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE saved_routes ENABLE ROW LEVEL SECURITY;

-- Saved Routes Policies
CREATE POLICY "Users can view their own routes"
    ON saved_routes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own routes"
    ON saved_routes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own routes"
    ON saved_routes FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own routes"
    ON saved_routes FOR DELETE
    USING (auth.uid() = user_id);

-- Index for faster queries
CREATE INDEX saved_routes_user_id_idx ON saved_routes(user_id);
CREATE INDEX saved_routes_created_at_idx ON saved_routes(created_at DESC);

-- ====================================
-- 3. Favorite Locations Table
-- ====================================
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    category TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Favorites Policies
CREATE POLICY "Users can view their own favorites"
    ON favorites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own favorites"
    ON favorites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own favorites"
    ON favorites FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own favorites"
    ON favorites FOR DELETE
    USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX favorites_user_id_idx ON favorites(user_id);
CREATE INDEX favorites_category_idx ON favorites(category);
CREATE INDEX favorites_created_at_idx ON favorites(created_at DESC);

-- ====================================
-- 4. Trip History Table
-- ====================================
CREATE TABLE trip_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_latitude DOUBLE PRECISION NOT NULL,
    start_longitude DOUBLE PRECISION NOT NULL,
    end_latitude DOUBLE PRECISION NOT NULL,
    end_longitude DOUBLE PRECISION NOT NULL,
    distance DOUBLE PRECISION NOT NULL,
    duration DOUBLE PRECISION NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE trip_history ENABLE ROW LEVEL SECURITY;

-- Trip History Policies
CREATE POLICY "Users can view their own trips"
    ON trip_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own trips"
    ON trip_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own trips"
    ON trip_history FOR UPDATE
    USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX trip_history_user_id_idx ON trip_history(user_id);
CREATE INDEX trip_history_started_at_idx ON trip_history(started_at DESC);

-- ====================================
-- 5. Truck Settings Table
-- ====================================
CREATE TABLE truck_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    height DOUBLE PRECISION NOT NULL DEFAULT 4.11,  -- meters (13'6")
    width DOUBLE PRECISION NOT NULL DEFAULT 2.44,   -- meters (8 ft)
    weight DOUBLE PRECISION NOT NULL DEFAULT 36.287, -- metric tons (80,000 lbs)
    length DOUBLE PRECISION NOT NULL DEFAULT 16.15,  -- meters (53 ft)
    hazmat BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE truck_settings ENABLE ROW LEVEL SECURITY;

-- Truck Settings Policies
CREATE POLICY "Users can view their own truck settings"
    ON truck_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own truck settings"
    ON truck_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own truck settings"
    ON truck_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- ====================================
-- 6. Updated At Triggers
-- ====================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_saved_routes_updated_at
    BEFORE UPDATE ON saved_routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_favorites_updated_at
    BEFORE UPDATE ON favorites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_truck_settings_updated_at
    BEFORE UPDATE ON truck_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ====================================
-- Setup Complete!
-- ====================================
-- Next steps:
-- 1. Copy and run this SQL in Supabase SQL Editor
-- 2. Configure Row Level Security as needed
-- 3. Add your Supabase URL and anon key to Info.plist
