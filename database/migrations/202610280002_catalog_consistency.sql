-- Serialize concurrent observations and normalize accents during candidate lookup.
create or replace function public.grocery_upsert_listings(p_listings jsonb, p_postal_code text default '', p_demo boolean default false)
returns void language plpgsql security invoker set search_path = public as $$
declare r jsonb; retailer_key text; store_key text; product_key text; listing_key text;
begin
  if jsonb_typeof(p_listings) <> 'array' or jsonb_array_length(p_listings)>100 then
    raise exception 'Invalid listing batch';
  end if;
  if coalesce(p_postal_code,'') !~ '^([0-9]{5})?$' then raise exception 'Invalid postal code'; end if;
  for r in select value from jsonb_array_elements(p_listings) loop
    retailer_key := r->>'source';
    store_key := md5(jsonb_build_array(retailer_key,coalesce(r->>'storeName',''))::text);
    listing_key := md5(jsonb_build_array(retailer_key,r->>'productUrl',store_key,coalesce(p_postal_code,''),p_demo)::text);
    perform pg_advisory_xact_lock(hashtextextended(listing_key,0));
    product_key := listing_key; -- Source-specific SKU; similar products are never merged.
    -- Old observations may enter history, but must not rewrite current SKU metadata.
    if exists(select 1 from prices where listing_id=listing_key and checked_at >= (r->>'checkedAt')::timestamptz) then
      insert into price_history values(listing_key,(r->>'checkedAt')::timestamptz,(r->>'priceCents')::bigint,(r->>'regularPriceCents')::bigint)
        on conflict(listing_id,checked_at) do nothing;
      continue;
    end if;
    insert into retailers values(retailer_key,r->>'retailer') on conflict(id) do update set name=excluded.name;
    insert into stores values(store_key,retailer_key,coalesce(r->>'storeName','')) on conflict(id) do nothing;
    insert into products values(product_key,r->>'productName',r->>'brand',(r->>'quantity')::numeric,r->>'unit')
      on conflict(id) do update set name=excluded.name,brand=excluded.brand,quantity=excluded.quantity,unit=excluded.unit;
    insert into listings values(listing_key,product_key,store_key,retailer_key,r->>'productUrl',coalesce(p_postal_code,''),p_demo)
      on conflict(id) do nothing;
    insert into price_history values(listing_key,(r->>'checkedAt')::timestamptz,(r->>'priceCents')::bigint,(r->>'regularPriceCents')::bigint)
      on conflict(listing_id,checked_at) do nothing;
    insert into prices values(listing_key,(r->>'priceCents')::bigint,(r->>'regularPriceCents')::bigint,'MXN',(r->>'checkedAt')::timestamptz,(r->>'checkedAt')::timestamptz+interval '1 hour')
      on conflict(listing_id) do update set price_cents=excluded.price_cents,regular_price_cents=excluded.regular_price_cents,checked_at=excluded.checked_at,expires_at=excluded.expires_at
      where excluded.checked_at > prices.checked_at;
  end loop;
end $$;

create or replace function public.grocery_search_listings(p_query text, p_postal_code text default '', p_limit integer default 20, p_demo boolean default false)
returns setof jsonb language sql stable security invoker set search_path = public as $$
 select jsonb_strip_nulls(jsonb_build_object(
   'source',l.source,'retailer',r.name,'storeName',nullif(s.name,''),
   'productName',p.name,'brand',p.brand,'quantity',p.quantity,'unit',p.unit,
   'priceCents',v.price_cents,'regularPriceCents',v.regular_price_cents,'currency',v.currency,
   'productUrl',l.product_url,'checkedAt',to_char(v.checked_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
 ))
 from listings l join products p on p.id=l.product_id join stores s on s.id=l.store_id
 join retailers r on r.id=s.retailer_id join prices v on v.listing_id=l.id
 where l.is_demo=p_demo and l.postal_code=coalesce(p_postal_code,'')
 and not exists (select 1 from unnest(regexp_split_to_array(lower(trim(p_query)), '\s+')) word
   where word<>'' and position(word in translate(lower(p.name),'áéíóúüñ','aeiouun'))=0)
 order by v.checked_at desc,l.id limit least(greatest(p_limit,1),100);
$$;

