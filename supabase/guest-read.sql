-- Ejecutar una sola vez en Supabase SQL Editor para permitir visitas de solo lectura.
create policy "Public can read categories"
on public.categories for select
using (true);

create policy "Public can read links"
on public.links for select
using (true);
