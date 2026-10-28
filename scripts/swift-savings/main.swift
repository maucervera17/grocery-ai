import Foundation
var ledger = SavingsLedger()
let listing = PriceListing(source:"test",retailer:"Test",productName:"Test 150ml",priceCents:6400,productUrl:"https://example.com/p",checkedAt:"2026-10-27")
ledger.products = [SelectedProduct(listing:listing,packages:2,usualPriceCents:7900)]
precondition(ledger.estimatedDifference == 3000)
ledger.confirm(paidCents:16000)
precondition(ledger.recordedDifference == -200)
ledger.confirm(paidCents:16000)
precondition(ledger.purchases.count == 1)
let restored = try JSONDecoder().decode(SavingsLedger.self,from:JSONEncoder().encode(ledger))
precondition(restored.recordedDifference == -200)
precondition(SavingsLedger.cents("79,50") == 7950)
precondition(SavingsLedger.cents("-5") == nil)
print("Swift savings: estimates, actual payment, negative difference, duplicate protection and persistence passed")
