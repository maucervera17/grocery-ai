-- Run against the migrated LOCAL database; all test mutations roll back.
begin;
do $$
declare original jsonb; changed jsonb; newer jsonb; got jsonb; n integer;
begin
  select * into original from grocery_search_listings('queso oaxaca','',20,true) limit 1;
  if original is null then raise exception 'Seed missing'; end if;
  perform grocery_upsert_listings(jsonb_build_array(original),'',true);
  perform grocery_upsert_listings(jsonb_build_array(original),'',true);
  select count(*) into n from grocery_search_listings('queso oaxaca','',20,true);
  if n <> 2 then raise exception 'Duplicate listing'; end if;
  newer := original || jsonb_build_object('checkedAt','2026-10-28T01:00:00.000Z','priceCents',12345);
  perform grocery_upsert_listings(jsonb_build_array(newer),'',true);
  changed := original || jsonb_build_object('productName','Incorrect stale metadata','priceCents',1);
  perform grocery_upsert_listings(jsonb_build_array(changed),'',true);
  select value into got from grocery_search_listings('queso oaxaca','',20,true) value where value->>'productUrl'=original->>'productUrl';
  if got->>'priceCents' <> '12345' then raise exception 'Old observation replaced newer one'; end if;
  if got->>'productName' <> original->>'productName' then raise exception 'Old metadata replaced newer metadata'; end if;
  perform grocery_upsert_listings(jsonb_build_array(original),'06700',false);
  select count(*) into n from grocery_search_listings('queso oaxaca','99999',20,false);
  if n <> 0 then raise exception 'Postal scope leaked'; end if;
  select count(*) into n from grocery_search_listings('queso oaxaca','06700',20,false);
  if n <> 1 then raise exception 'Live observation missing'; end if;
  if has_function_privilege('anon','grocery_search_listings(text,text,integer,boolean)','EXECUTE') then raise exception 'Anon can execute RPC'; end if;
  if has_table_privilege('authenticated','prices','SELECT') then raise exception 'Authenticated can read prices'; end if;
  raise notice 'PASS: repeat import, freshness, metadata, postal scopes, demo/live and access controls';
end $$;
rollback;
