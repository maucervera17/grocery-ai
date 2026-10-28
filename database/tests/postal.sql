begin;
do $$
declare result jsonb;
begin
  perform public.grocery_upsert_listings('[{"source":"postal-test","retailer":"Postal test","storeName":"Test branch","productName":"Postal test milk","quantity":1,"unit":"L","priceCents":2000,"currency":"MXN","productUrl":"https://example.com/postal-test","checkedAt":"2026-10-28T03:00:00.000Z","locationEvidence":{"postalCode":"52997","fulfillment":"delivery","availability":"in_stock","text":"Synthetic database test"}}]'::jsonb,'52997',false);
  select value into result from public.grocery_search_listings('postal test','52997',20,false) value limit 1;
  if result->'locationEvidence'->>'postalCode' <> '52997' then raise exception 'Postal evidence lost'; end if;
  if exists(select 1 from public.grocery_search_listings('postal test','11220',20,false)) then raise exception 'Cross-postal leak'; end if;
  raise notice 'PASS: postal evidence roundtrip and scope isolation';
end $$;
rollback;
