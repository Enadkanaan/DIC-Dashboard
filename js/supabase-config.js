/**
 * Supabase client configuration — DIC Dashboard
 *
 * Replace SUPABASE_URL and SUPABASE_ANON_KEY with your project values.
 * Find them in: Supabase Dashboard → Project Settings → API
 *
 * The anon key is safe to expose in a public frontend — Row Level Security
 * policies on the database enforce all access rules.
 */

const SUPABASE_URL      = 'https://mgszueovvubfafctglsp.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nc3p1ZW92dnViZmFmY3RnbHNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNDcyNDgsImV4cCI6MjA5NjgyMzI0OH0.gawMahhfpIlWyima30-cGXQ37N-ELOE9aOw7oBuQ5ow';

export const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true
  },
  realtime: {
    params: {
      eventsPerSecond: 10
    }
  }
});
