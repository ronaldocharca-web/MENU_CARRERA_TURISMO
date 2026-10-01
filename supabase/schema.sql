create extension if not exists "pgcrypto";

create type public.user_role as enum ('member', 'admin');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 120),
  role public.user_role not null default 'member',
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.links (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 120),
  url text not null check (char_length(url) <= 2048),
  normalized_url text not null,
  description text not null default '' check (char_length(description) <= 500),
  category_id uuid not null references public.categories(id),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1 check (revision > 0)
);

create table public.favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  link_id uuid not null references public.links(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, link_id)
);

insert into public.categories (name)
values ('Universidad'), ('Proyectos'), ('Herramientas'), ('Documentos'), ('Otros')
on conflict (name) do nothing;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.links enable row level security;
alter table public.favorites enable row level security;

create or replace function public.is_active_member()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and active = true); $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and active = true and role = 'admin'); $$;

create policy "Users read own profile or admins read all" on public.profiles for select using (auth.uid() = id or public.is_admin());
create policy "Users create own pending profile" on public.profiles for insert with check (auth.uid() = id and role = 'member' and active = false);
create policy "Users edit own name" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Admins activate members" on public.profiles for update using (public.is_admin() and id <> auth.uid()) with check (public.is_admin());
create policy "Active members read categories" on public.categories for select using (public.is_active_member());
create policy "Public can read categories" on public.categories for select using (true);
create policy "Admins manage categories" on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy "Active members read links" on public.links for select using (public.is_active_member());
create policy "Public can read links" on public.links for select using (true);
create policy "Active members create links" on public.links for insert with check (public.is_active_member() and created_by = auth.uid());
create policy "Owners or admins update links" on public.links for update using (public.is_active_member() and (created_by = auth.uid() or public.is_admin()));
create policy "Owners or admins delete links" on public.links for delete using (public.is_active_member() and (created_by = auth.uid() or public.is_admin()));
create policy "Users manage own favorites" on public.favorites for all using (public.is_active_member() and user_id = auth.uid()) with check (public.is_active_member() and user_id = auth.uid());

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin insert into public.profiles (id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter publication supabase_realtime add table public.links;
alter publication supabase_realtime add table public.categories;
alter publication supabase_realtime add table public.favorites;
