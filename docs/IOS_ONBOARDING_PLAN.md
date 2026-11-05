# Barasu iOS — Onboarding plan

Status: **implemented** (`ios/GroceryAI/Features/Onboarding`, `Features/Paywall`). See §6 for the final decisions, which override earlier sections where they differ. Scope: iOS app (`ios/GroceryAI`). UI copy is es-MX, the same as the rest of the app. Visual rules come from [IOS_DESIGN_SYSTEM.md](IOS_DESIGN_SYSTEM.md). This plan does not add any new tokens.

---

## 1. Research summary: what works and what doesn't

### 1.1 What the data says

| Finding | Source | What it means for Barasu |
|---|---|---|
| 80–82% of trial starts happen on install day. Adapty puts it at 89.4%. Users who don't start a trial in the first session rarely start one later. | RevenueCat *State of Subscription Apps 2025*; Adapty *State of In-App Subscriptions* | The paywall goes inside onboarding, not days later. |
| Median download-to-paid is 12.11% for hard-paywall apps and 2.18% for freemium. Trial-to-paid in Latin America has a median of **25%**, well below other regions. | RevenueCat 2025 (summary by RocketShip HQ) | Mexico converts worse after a trial, so the trial has to show real value. One full shopping cycle is the minimum. |
| Longer trials (17–32 days) correlate with 45.7% trial-to-paid. Trials of 4 days or less: 26.8%. This is a correlation, not proof of cause. | RevenueCat 2025 | Use a 7-day trial, not 3, so it covers at least one weekly shop. |
| Multi-page onboarding paywalls convert at 12.41% vs 9.07% for single-page (+37%, 40M+ opens, Feb–May 2026). | Superwall, May 2026 | Use a 3-page paywall: value → trial timeline → plans. |
| Top apps run long quizzes: Cal AI has 29 screens and 16 questions in about 2¼ minutes. QUITTR has 35+. Every question visibly feeds the result. | ASOitis teardowns (Oct 2026); mecurylab Cal AI teardown | Length is fine **if every question has an obvious purpose** and the flow ends in a personal result. |
| The biggest difference between top onboardings is not length. It is whether the user **leaves with a personal result before the price.** | ASOitis | The quiz must produce a savings estimate, and the demo must produce a real price comparison, before the paywall. |
| Cal AI opens with the product working (camera on food). No tagline, no feature tour. | Cal AI teardowns | The first screen is an animated loop of Barasu working (list → store prices), not a slogan. |
| "Building your plan" loaders (labor illusion) are used by Noom, Lose It, Speak and others. Only about 9 of ~751 apps use them, so they still stand out. They work best when the copy echoes the user's answers. | Lazyweb research; RevenueCat Noom teardown; Adapty | One loader before the result. In Barasu it can do real work (geocoding the postal code, warming the backend). |
| Apple HIG: onboarding should be "fast, fun, and optional". Teach through interaction. Let people try the product before prompting for purchase. | Apple HIG, Onboarding | The demo is interactive (their list, their products). There is no read-only tutorial. Optional steps have a Skip button. |
| Permission priming is allowed: **one button labelled "Continuar"**, no way out before the system alert, no re-asking after a denial. ATT is stricter. Offer an alternative when a permission is denied (5.1.1(iv)). | Apple HIG Privacy; App Review 5.1.1 (via ASOitis) | Location already has a manual postal-code fallback (`LocationRequestView`). Notifications are primed once. No ATT. |
| Don't require an account unless it protects something real (5.1.1(v)). | App Review Guidelines | No sign-up in onboarding. Barasu has no user accounts today. |
| Paywall must show the plan name, the billed price as the most prominent number, trial length and post-trial price, Terms and Privacy links, and Restore. Trial-led CTAs that outweigh the price have been rejected under 3.1.2(c). | App Review 3.1.2; Apple "Auto-renewable Subscriptions" | These go in the paywall spec (§5) even while it's a placeholder. |
| A stripped-down paywall beat a feature-comparison chart by 111%. Use 1–3 plans with a clear default, and push annual. | Superwall | Two plans (Annual pre-selected, Monthly). No comparison table. |

### 1.2 Mexico data used for the benefit claims

The repo has a strict honesty rule: no invented prices or savings (see README and `WEEKLY_SHOPPING.md`). The benefit screens therefore use **public, citable numbers** and label every personal number as an estimate.

- **INEGI ENIGH 2024:** the average household spends **$17,982 MXN per quarter** on food, drinks and tobacco, about **$6,000/month**. That is 37.7% of monetary spending. Use it as the anchor on the spending question.
- **Profeco "Quién es Quién en los Precios", Sep 2026:** the same 24-product basket cost $734 at the cheapest store and $920.50 at the most expensive, a **$186.50 gap (~25%)** nationally. Within one city the gap was $34.80 in CDMX (4.3%), $49.30 in Villahermosa (6.3%) and $70.38 in Monterrey (8.7%). Profeco also notes that **no single chain is cheapest for every product**. That is exactly Barasu's split-basket thesis.

**Savings estimate formula (pure function, unit-tested):**

```
monthlySpend   = midpoint of the user's spend range
lowEstimate    = monthlySpend × 0.04   // within-city single-store gap (CDMX, Profeco)
highEstimate   = monthlySpend × 0.09   // within-city single-store gap (Monterrey, Profeco)
```

Show it as a range ("entre $240 y $540 al mes"), plus the annual high figure. Always add the footnote: *"Estimación con diferencias de precio publicadas por Profeco. Tu ahorro real depende de tu lista y tu zona."* Never show a single precise number. Never call it a guarantee.

### 1.3 What to avoid

- Feature-tour carousels with no interaction. Apple's WWDC21 talk says plainly that people skip them.
- Fake social proof such as invented ratings, user counts or testimonials. We don't have any yet, so this step is left out until real data exists.
- Fake urgency (countdown timers, "offer ends today").
- Asking a question whose answer we never use.
- Showing the paywall before any personal result.
- The words "DEMO" / "Demostración" in the UI (design system §21). Call it **"Pruébalo"**.
- Decorative illustrations (design system §2.8). Visuals are **real Barasu UI** (`SurfaceCard`, `StoreResultCard`, `ProductThumbnail`, retailer logos) and SF Symbols.
- Asking for the rating prompt during onboarding.

---

## 2. Flow overview

About **22 screens, roughly 2½ minutes**, in six acts. A thin progress bar runs across Acts 1–4. The paywall does not show progress.

```
Act 0  Hook                 1  Bienvenida (live product loop)
Act 1  Quiz                 2  Intro  →  3–11 Questions  →  12 Código postal
Act 2  Result & benefit     13 Loader  →  14 Tu ahorro estimado  →  15 Así lo logras
Act 3  Import               16 Trae tu lista  →  17 Revisa tu lista
Act 4  Pruébalo             18 Elige 1–2 productos  →  19 Comparando  →  20 Resultado
Act 5  Convert              21 Recordatorios (notif. primer)  →  22a/b/c Paywall
Exit                        App opens on Agente with the imported list as the draft
```

**Why this order:**
1. The **result comes before the features.** The user first learns *what they get* (their estimate), then *how* (three capabilities).
2. **Import comes right before the demo**, so the demo runs on *their* products. This is the "aha" moment.
3. The **paywall comes straight after the demo result**, which is peak motivation (Superwall: trigger right after the aha).
4. **Continuity after the paywall:** the imported list is already waiting in the Agente tab as the draft. Whether or not they pay, the setup work isn't lost.

---

## 3. Shared UI rules for every onboarding screen

One scaffold, `OnboardingScaffold`, keeps every step consistent:

```
┌───────────────────────────────┐
│ ‹        ▬▬▬▬▬▬▬▬▬▭▭▭▭        │  back chevron + progress (thin, brandPrimary on borderSubtle)
│                               │
│ Título en .largeTitle bold    │  AppTypography.screenTitle
│ Subtítulo en .body secondary  │  one sentence, says why we ask
│                               │
│ ┌───────────────────────────┐ │
│ │ 🧍  Solo yo             ◯ │ │  OptionRow (cellBackground, radius 12, 44pt+)
│ └───────────────────────────┘ │
│ ┌───────────────────────────┐ │
│ │ 👫  2 personas          ● │ │  selected: brandPrimary 1.5pt border + brandSecondary fill
│ └───────────────────────────┘ │
│              …                │
│                               │
│ [        Continuar          ] │  PrimaryButton, pinned via safeAreaInset(edge: .bottom)
└───────────────────────────────┘
```

- **Single-select:** tapping an option selects it and auto-advances after about 250 ms, so no Continue button is needed. **Multi-select:** Continue stays disabled (55% opacity) until at least one option is chosen. This is the Cal AI "button wakes up" detail.
- **Back** keeps previous answers. **Swipe-back** is supported (NavigationStack push).
- Option rows use **SF Symbols**, not emoji, to follow the design system. Emoji appear above only for sketching.
- Each question's subtitle says why we ask, e.g. *"Lo usamos para estimar tu ahorro."* This is the "every question has an obvious purpose" rule.
- Colors only come from `theme.colors(for:)`. Blue is used only for selection and actions. Surfaces stay neutral in dark mode.
- Light mode, dark mode, Dynamic Type up to AX5 (options wrap and the scaffold scrolls), VoiceOver (`.isSelected` trait, step announced as "Paso 4 de 12"), and Reduce Motion (loops and loaders become cross-fades).
- Haptics: `.sensoryFeedback(.selection, trigger:)` on option tap, `.success` on results.
- Transitions: a native push between steps. No custom page curls.

---

## 4. Screen-by-screen spec

Legend: **Captures** = what gets stored in `OnboardingAnswers`. **Used by** = which later screen or feature reads it. A question with no "Used by" gets cut.

### Act 0: Hook

#### 1. Bienvenida
- **Purpose:** explain the product in about 3 seconds by showing it work (the Cal AI pattern).
- **UI:** Barasu wordmark (adaptive asset) at top. In the middle, an **auto-playing loop built from real components**:
  1. A user chat bubble types *"Leche, huevos, arroz y papel de baño"*.
  2. It turns into a compact `DraftCard` with 4 rows and `ProductThumbnail`s.
  3. Three `StoreResultCard`s slide in (Walmart, Bodega Aurrera, Chedraui logos) with subtotals. The cheapest gets the `checkmark.seal.fill` "Mejor opción" label.
  4. The loop restarts.

  This uses static fixture data from `MockFixtures`, never live prices.
- **Copy:** Title *"Tu súper, al mejor precio."* Subtitle *"Escribe tu lista y Barasu compara Walmart, Bodega Aurrera y Chedraui por ti."*
- **CTA:** `PrimaryButton("Empezar")`. No sign-in link (no accounts).
- **Reduce Motion:** show the final frame, static.

### Act 1: Quiz

#### 2. Intro
- **Copy:** *"Armemos tu plan de ahorro"* / *"Son 10 preguntas rápidas. Con ellas calculamos cuánto podrías ahorrar."*
- **UI:** three lines with SF Symbols: `list.bullet` *Tus hábitos*, `chart.bar` *Tu ahorro estimado*, `cart` *Una prueba con tu lista*.
- **CTA:** *"Comenzar"*.

#### 3. ¿Para cuántas personas compras?
- Options: *Solo para mí* · *2 personas* · *3 a 4 personas* · *5 o más*
- **Captures:** `householdSize`. **Used by:** sample list size (16), copy on 14 (*"para tu hogar de 4"*).

#### 4. ¿Cada cuánto haces el súper?
- Options: *Varias veces por semana* · *Cada semana* · *Cada 15 días* · *Una vez al mes*
- **Captures:** `shoppingFrequency` (trips/month: 10 / 4 / 2 / 1). **Used by:** 14 (*"en tus 4 compras al mes"*), 21 (reminder cadence), 22b (trial copy: *"7 días = tu próxima compra"*).

#### 5. ¿Cuánto gastas al mes en el súper?
- Subtitle hint: *"Un hogar en México gasta en promedio unos $6,000 al mes en alimentos y bebidas (INEGI)."*
- Options: *Menos de $2,000* · *$2,000 – $4,000* · *$4,000 – $7,000* · *$7,000 – $10,000* · *Más de $10,000* · *No estoy seguro*
- *No estoy seguro* uses an estimate from household size: ENIGH $6,000 scaled by size.
- **Captures:** `monthlySpendRange`. **Used by:** savings formula (14, 22a).

#### 6. ¿Dónde compras normalmente? (multi-select)
- Options with retailer logos (existing `RetailerLogo` assets): Walmart · Bodega Aurrera · Chedraui · Soriana · La Comer · Costco · Mercado o tianguis · Otro
- **Captures:** `usualStores`. **Used by:** 13 loader copy. On 20 the result highlights *"vs. tu tienda habitual"* when it is one of the three supported chains.
- **Honesty note:** if they choose only unsupported stores, 14 says *"Hoy comparamos Walmart, Bodega Aurrera y Chedraui"* rather than implying coverage.

#### 7. ¿Comparas precios antes de comprar?
- Options: *Nunca, compro donde siempre* · *A veces, con folletos u ofertas* · *Siempre, aunque me toma tiempo*
- **Captures:** `comparesToday`. **Used by:** interstitial copy on 8.

#### 8. Insight (interstitial, no question)
- **Purpose:** teach the benefit with a real fact and reflect their answer back.
- **UI:** a `SurfaceCard` with two horizontal bars: *"Mismos 24 productos"*, **$734** vs **$920.50**, and a `StatusBadge` reading *"$186 de diferencia"*. A footnote with source: *"Profeco, Quién es Quién en los Precios, sept. 2026."*
- **Copy varies by answer 7:**
  - *Nunca* → *"Comprar siempre en la misma tienda puede costarte más de lo que crees."*
  - *A veces* → *"Las ofertas cambian cada semana. Barasu las revisa por ti."*
  - *Siempre* → *"Ya sabes que vale la pena. Ahora sin perder tiempo."*
- **CTA:** *"Continuar"*.

#### 9. ¿Qué es lo más importante para ti? (multi, max 2)
- Options: *Ahorrar dinero* · *Ahorrar tiempo* · *No olvidar nada* · *Organizar mis compras*
- **Captures:** `goals`. **Used by:** order of the three benefit rows on 15 and 22a (lead with their goal).

#### 10. ¿Qué es lo más difícil del súper? (multi)
- Options: *Gasto más de lo planeado* · *No sé dónde está más barato* · *Se me olvidan cosas* · *Hacer la lista me toma tiempo* · *Repetir la misma lista cada semana*
- **Captures:** `painPoints`. **Used by:** 15 ("Así lo logras"): each pain maps to a capability (see 15).

#### 11. ¿Cómo haces tu lista hoy?
- Options: *En papel* · *En las notas del celular* · *En WhatsApp* · *En Recordatorios* · *De memoria* · *No hago lista*
- **Captures:** `listHabit`. **Used by:** **16 pre-selects the matching import method**: paper → *Tomar foto*, notes/WhatsApp/Reminders → *Pegar texto*, memory/none → *Dictar* or *Lista sugerida*. This is a question with a very visible payoff.

#### 12. ¿Dónde haces el súper? (postal code)
- **Purpose:** needed for the real comparison in Act 4. It already exists as `LocationRequestView`.
- **UI:** reuse `LocationRequestView` inside the scaffold. *"Usar ubicación actual"* (bordered button) or type the postal code.
- **Permission priming:** tapping *Usar ubicación actual* *is* the explicit user action. The system prompt appears right away, so no separate primer screen is needed. If denied, the postal-code field is the alternative (5.1.1(iv)). Never re-ask.
- **Captures:** `postalCode` → written to `AppState.postalCode`. Only the postal code is stored, no coordinates (existing rule).
- **Skip:** *"Ahora no"* uses no postal code. The demo then falls back to published prices without zone (§4 Act 4).

### Act 2: Result & benefit

#### 13. Loader: "Preparando tu plan"
- **Purpose:** labor illusion **plus real work**. During this time we (a) fire a warm-up `GET /health` to wake Render's cold start, and (b) prefetch the reference comparison for the demo fallback.
- **UI:** the Barasu agent avatar (44 pt, existing `AgentAvatarView`) and a checklist that ticks line by line (about 0.8 s each, about 3.5 s total, never longer than the real work + 1 s):
  - ✓ *Hogar de 3–4 personas, súper cada semana*
  - ✓ *Revisando tiendas cerca de 06700*
  - ✓ *Comparando Walmart, Bodega Aurrera y Chedraui*
  - ✓ *Calculando tu ahorro*
- Lines are built from the user's answers. Auto-advances. No CTA.

#### 14. Tu ahorro estimado (the personal result)
- **UI:**
  ```
  Podrías ahorrar
  $240 – $540          ← .largeTitle bold, textPrimary
  al mes               ← .title3 secondary
  ┌ SurfaceCard ─────────────────────┐
  │ Hasta $6,480 al año              │
  │ En tus ~4 compras al mes         │
  │ Comparando 3 súpers cerca de ti  │
  └──────────────────────────────────┘
  ⓘ Estimación con diferencias de precio publicadas por Profeco.
    Tu ahorro real depende de tu lista y tu zona.
  ```
- The number counts up from $0 (Reduce Motion: static). The money figure stays `textPrimary`, not green, because the design system keeps green for status. A small `StatusBadge(.success)` reading *"Estimado"* can sit next to the title.
- **CTA:** *"¿Cómo lo hago?"*

#### 15. Así lo logras (product benefits)
- **Purpose:** the "show the product" requirement, kept to **one scrollable screen with three cards**, not a 3-page carousel.
- Each card is a **mini live snippet of real UI** with one line of copy. Order follows `goals`/`painPoints`:

  | Pain point / goal | Card | Visual |
  |---|---|---|
  | *No sé dónde está más barato* / *Ahorrar dinero* | **Compara 3 súpers en segundos** | mini `StoreResultCard` stack with "Mejor opción" |
  | *Hacer la lista me toma tiempo* / *Ahorrar tiempo* | **Escribe o dicta tu lista** | mini composer with mic button (Liquid Glass, as in the app) |
  | *Repetir la misma lista* / *No olvidar nada* | **Repite tu compra en un toque** | mini `OrderHistoryRow` + "Repetir compra" |

- **CTA:** *"Probar con mi lista"*.

### Act 3: Import

#### 16. Trae tu lista
- **Copy:** *"Trae tu lista del súper"* / *"La usaremos para tu prueba. Puedes editarla después."*
- **Options (large OptionRows; the one matching Q11 is pre-selected with a "Recomendado" badge):**

  | Option | Implementation | Permission |
  |---|---|---|
  | `camera` **Tomar foto de tu lista** | `PhotosPicker` + camera (`UIImagePickerController` wrapper or `DataScannerViewController`). Run Vision `RecognizeTextRequest` (iOS 18+ Swift API, `.accurate`, `es-ES` supported). Send the joined lines to the existing `updateDraft` API to parse quantities and units. | Camera: the system prompt is triggered by the user's tap, so no primer is needed. Needs `NSCameraUsageDescription`. |
  | `doc.on.clipboard` **Pegar texto** | `TextEditor` sheet with a `PasteButton` (no paste-permission alert). Send to `updateDraft`. Works for Notes, WhatsApp and Reminders exports. | None |
  | `mic` **Dictar** | Reuse the existing voice composer / `VoiceConversationController` | Mic (already in Info.plist) |
  | `square.and.pencil` **Escribir** | Plain text field → `updateDraft` | None |
  | `basket` **Usar una lista sugerida** | Pre-built list sized by `householdSize` (from `MockFixtures` products: leche, huevos, arroz, pollo, papel…) | None |

- **Skip:** *"Ahora no"* → suggested list (the demo always has something to run on).
- **v2 idea (not in this plan):** import straight from the Reminders app via EventKit `requestFullAccessToReminders`. It needs full Reminders access, which is a heavy ask in onboarding, so it is deferred.

#### 17. Revisa tu lista
- **UI:** parsed items as `DraftProductRow`s inside a `SurfaceCard` with *"N productos"*. Quantities are editable (existing `ProductEditorView` in a `.medium` sheet). Swipe to delete.
- **Loading state:** while `updateDraft` parses, show the existing inline agent activity indicator (*"Leyendo tu lista…"*).
- **Errors:** OCR found nothing or parsing failed → *"No pude leer tu lista. Intenta otra foto o pégala como texto."* with a button back to 16. Keep anything already parsed.
- **Captures:** `importedItems: [ProductRequest]`. These become `AppState.draft` at the end of onboarding.
- **CTA:** *"Se ve bien"*.

### Act 4: Pruébalo (demo)

#### 18. Elige 1 o 2 productos
- **Copy:** *"Probemos con 2 productos"* / *"Te mostramos dónde están más baratos ahora mismo."*
- **UI:** the imported list as selectable rows (reuse `SelectableProductRow`). **The first 2 are pre-selected**, preferring items with known demo coverage (leche, huevos, arroz). Max 2. A third tap deselects the oldest.
- **CTA:** *"Comparar precios"* (same label as the main app).

#### 19. Comparando
- **Real call:** `comparisonService.compare(items: selected, postalCode:)` with the existing client.
- **UI:** the existing `ComparisonLoadingView` style: three retailer rows that tick as their results arrive.
- **Time budget and fallback (important, because the compare timeout is 95 s and Render can cold-start):**
  - The warm-up already happened on screen 13.
  - **Soft cap 12 s.** If the live call hasn't returned, show the **reference result prefetched on 13** (a real comparison for the same 2 products with no postal code, or a recorded fixture as a last resort), labelled *"Precios publicados el {fecha}"*. Never show invented prices.
  - If the live call finishes later, swap in the live result quietly only if the user is still on 20.
- Auto-advances to 20.

#### 20. Resultado
- **UI** (prices below are illustrative only; the screen renders whatever the comparison returns):
  ```
  ✓ Mejor opción                          (statusSuccess label, existing ComparisonSummaryCard style)
  Leche Lala 1 L     Bodega Aurrera  $26.50   vs $29.90 en Walmart
  Huevo 12 pzas      Chedraui        $38.00   vs $44.50 en Bodega Aurrera
  ─────────────────────────────────────────
  Ahorras $9.90 en solo 2 productos
  Tu lista tiene 12 productos más. ¿Comparamos todos?
  ⓘ Precios publicados; confirma en tienda.
  ```
  Each line uses `ProductThumbnail`, `RetailerLogo` and `MatchStatusIndicator` (the existing match legend semantics).
- **Honest copy variants:**
  - Savings > 0 → as above.
  - Savings = 0 / same store cheapest → *"Tu tienda habitual ya es la más barata en estos 2. Con tu lista completa suelen aparecer diferencias."*
  - Partial (no match for one item) → show the matched one and mark the other with the existing unmatched style. Don't hide it.
  - Total failure → *"No pudimos consultar precios ahora."* Still continue to 21. Don't block onboarding on the backend.
- **CTA:** *"Comparar mi lista completa"* → goes to the paywall. This is the natural "unlock" moment.

### Act 5: Convert

#### 21. Recordatorios (notification primer)
- **Purpose:** (a) trial reminder, which lowers trial anxiety (Superwall/Cal AI pattern); (b) a weekly *"¿Hacemos tu lista?"* nudge on their shopping cadence.
- **UI:** `bell.badge` symbol, title *"Te avisamos antes de que termine tu prueba"*, subtitle *"Y un recordatorio para tu súper {cada semana}."*
- **One button only: "Continuar"**, which triggers `UNUserNotificationCenter.requestAuthorization`. There is no close or skip on this screen (HIG rule). Whatever the user answers, advance and never re-ask.
- If notifications are already determined (reinstall), skip this screen.

#### 22. Paywall: 3 pages (placeholder, no StoreKit yet)
Multi-page per the Superwall data. Close button: see **Decision D1**.

**22a. Value (personalized)**
- Title: *"Ahorra hasta $540 al mes"* (their high estimate, from §1.2).
- Three checkmark rows in `goals` order: *Compara tu lista completa en 3 súpers* · *Dicta o pega tu lista, Barasu la arma* · *Historial y repetir compra*.
- Their demo result as a small card: *"Ya ahorraste $9.90 con 2 productos"*.
- CTA *"Continuar"*.

**22b. Trial timeline (anxiety reducer)**
```
● Hoy        Acceso completo. Compara tu próxima compra.
● Día 5      Te enviamos un recordatorio.
● Día 7      Inicia tu suscripción. Cancela antes y no pagas nada.
```
- Copy uses their frequency: *"7 días alcanzan para tu próxima compra semanal."*
- CTA *"Continuar"*.

**22c. Plans + purchase**
```
┌ Anual ─────────────── [Ahorra 33%] ┐  ← pre-selected (brandPrimary border)
│ $399 / año · 7 días gratis           │
│ equivale a $33.25 al mes             │  ← secondary, smaller than billed price
└──────────────────────────────────────┘
┌ Mensual ────────────────────────────┐
│ $49 / mes                            │
└──────────────────────────────────────┘
[ Empezar 7 días gratis ]              ← PrimaryButton
Después $399 al año. Cancela cuando quieras.
Restaurar compras · Términos · Privacidad
```
- **Prices are placeholders** (D2). The billed amount (*$399 / año*) is the most prominent price (3.1.2). Trial length and post-trial price sit right under the CTA. Restore, Terms (EULA) and Privacy links are required even in the placeholder.
- **Placeholder behaviour:** `MockSubscriptionService.purchase(plan:)` waits about 1 s, returns success and sets `hasActiveSubscription = true` locally (DEBUG only). Restore returns "no purchases found".
- **After purchase or close:** onboarding is marked complete, `AppState.draft` is set to the imported list, `postalCode` is persisted, and the app lands on **Agente** with an agent message: *"Tu lista está lista. Toca Comparar precios cuando quieras."*

---

## 5. Architecture (for implementation later)

```
ios/GroceryAI/Features/Onboarding/
  OnboardingFlowView.swift        // NavigationStack(path:) over OnboardingStep
  OnboardingModel.swift           // @Observable: answers, navigation, side effects
  OnboardingStep.swift            // enum, one case per screen, progress index
  OnboardingAnswers.swift         // Codable struct (household, frequency, spend, stores, …)
  SavingsEstimator.swift          // pure func; unit-tested
  Scaffold/OnboardingScaffold.swift, OnboardingProgressBar.swift, OptionRow.swift
  Steps/WelcomeStep.swift, QuestionStep.swift (generic over options), InsightStep.swift,
        PlanLoaderStep.swift, SavingsResultStep.swift, BenefitsStep.swift,
        ImportMethodStep.swift, ImportReviewStep.swift, DemoPickStep.swift,
        DemoComparingStep.swift, DemoResultStep.swift, NotificationPrimerStep.swift
  Import/ListTextRecognizer.swift // Vision RecognizeTextRequest wrapper
ios/GroceryAI/Features/Paywall/
  PaywallFlowView.swift, PaywallValuePage.swift, PaywallTrialPage.swift, PaywallPlansPage.swift
ios/GroceryAI/Domain/Services/SubscriptionServicing.swift
ios/GroceryAI/Data/Mock/MockSubscriptionService.swift
```

- **Gating:** `RootView` shows `OnboardingFlowView` in a `fullScreenCover` while `!hasCompletedOnboarding`. Store the flag in `LocalAppStateRecord` (SwiftData, next to draft/postalCode) so it stays with the rest of the local state. Add a DEBUG-only *"Reiniciar onboarding"* row in `AgentSettingsView`.
- **Generic question step:** most of steps 3–11 are one `QuestionStep<Option>` driven by data (title, subtitle, options, single or multi, max selections). This keeps the file count down and makes it easy to reorder or remove questions.
- **Services:** inject `AgentServicing` / `ComparisonServicing` (already protocols) so previews and tests use the mocks.
- **StoreKit later:** `SubscriptionServicing` gets a `StoreKitSubscriptionService` built on StoreKit 2 (`Product.products(for:)`, `purchase()`, `Transaction.currentEntitlements`). The 3 paywall pages keep their UI. Only page 22c binds to real `Product.displayPrice` and `subscription.introductoryOffer`.
- **Info.plist additions:** `NSCameraUsageDescription` (*"Barasu usa la cámara para leer tu lista del súper."*). Mic and location are already present.
- **Analytics (no SDK today):** define an `OnboardingEvent` enum (`stepViewed(step)`, `answer(step, value)`, `importMethod`, `demoResult(savingsCents | failed | fallback)`, `paywallViewed(page)`, `purchaseTapped(plan)`, `dismissed(step)`) with a no-op logger. It gets connected later so we can measure per-screen drop-off. Nobody publishes per-screen benchmarks, so our own data is the only reference.
- **Tests:** `SavingsEstimator` (ranges, "no estoy seguro" fallback, rounding to $10). The `OnboardingModel` step sequence (skip paths for location, import and notifications). Mapping from import method to pre-selection. Demo fallback when the compare call times out (mock service with delay).

---

## 6. Decisions needed before implementation

**Decided and implemented:**

| # | Decision | Outcome |
|---|---|---|
| D1 | Hard or soft paywall | **Hard.** No close button anywhere. Onboarding is a non-dismissable `fullScreenCover` shown while `!(hasCompletedOnboarding && isPro)`. |
| D2 | Prices (MXN) | **$200/mes, $2,000/año** (badge "Ahorra 17%"). Placeholders that can change later. |
| D3 | Trial length | 7 days on annual only. Monthly has no trial. |
| D4 | Free tier | **None**, because the paywall is hard. With no StoreKit yet, `PlaceholderSubscriptionService` grants Pro locally when the user taps purchase. |
| D5 | Chains in copy | Walmart, Bodega Aurrera and Chedraui (the app's `RetailerID` set). |
| D6 | Demo backend | Live `compare` call. After 12 s it shows "Sigue buscando precios…". At a 45 s hard cap the call is treated as failed, and the honest failure variant appears. **There is no fixture or prefetched fallback**, so prices are never invented. Screen 13 only warms up `GET /health`. "Comparando" stays on screen for at least 1.5 s so a fast response is still readable. |
| D7 | Access password on a fresh install | **Asked inside onboarding.** The API needs a per-tester Basic-auth password (early access), and Agent settings sit behind the hard paywall, so a new step `.access` ("Ingresa tu contraseña de acceso") sits between Beneficios and Trae tu lista, before the first API call. It is skipped when Keychain already has a password. "Continuar" checks the password with `GET /v1/voice/status` (200 = valid, 401 = invalid; it spends no search or voice credits), then saves it with `APIAccess.savePassword`. Invalid password or no network shows an inline error and stays on the step. **"No tengo contraseña"** continues with the suggested list; "Probemos con 2 productos" then skips the comparison and the result screen says honestly that comparing prices needs access and can be added later in Ajustes. No prices are shown. |
| D8 | Privacy policy | `web/privacidad.html` (es-MX, based on what the code does), served by Vercel at `/privacidad.html` (and `/privacidad` through a rewrite) and by the local Fastify server without auth. iOS links it from the paywall and from Ajustes → Legal through `LegalLinks.privacy`. |

Import errors (H3): access, network and "no products recognized" have different copy per import method, and the review step offers "Usar una lista sugerida" next to "Intentar de nuevo".

Extra: in DEBUG builds, Configuración → Depuración → "Reiniciar onboarding" resets the onboarding flag and Pro status. Also DEBUG-only: launch arguments `-onboardingStep <case>`, `-paywallPage <page>` and `-onboardingDemoFail` open screens directly for screenshots.

---

## 7. Sources

- RevenueCat, *State of Subscription Apps 2025*: https://www.revenuecat.com/pdf/state-of-subscription-apps-2025.pdf
- RocketShip HQ, summary of RevenueCat 2025 benchmarks: https://www.rocketshiphq.com/revenuecat-state-of-subscription-apps-2025-summary/
- RevenueCat, *Fix your onboarding funnel first*: https://www.revenuecat.com/blog/growth/fix-onboarding-funnels
- RevenueCat, *Inside Noom's web-to-app onboarding funnel*: https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel
- Superwall, *Multi-page onboarding paywalls convert 37% better*: https://superwall.com/blog/new-postmulti-page-onboarding-paywalls-convert-37-better-than-single-page-heres-why
- Superwall, *Two paywall trends driving ARPU gains*: https://superwall.com/blog/two-paywall-trends-driving-arpu-gains
- Superwall, *Best practices*: https://superwall.com/blog/superwall-best-practices-winning-paywall-strategies-and-experiments-to/
- Adapty, *How to personalize onboarding and paywalls*: https://adapty.io/blog/how-to-personalize-onboarding-and-paywalls-in-your-mobile-app/
- ASOitis, *App onboarding that converts* (Cal AI, QUITTR, Glowly): https://asoitis.com/blog/app-onboarding
- ASOitis, *Cal AI teardown*: https://asoitis.com/case-studies/cal-ai
- mecurylab, *Cal AI paywall teardown*: https://app.mecurylab.com/teardowns/calai-paywall
- Lazyweb, *"Building your plan" loader prevalence*: https://www.lazyweb.com/research/building-your-plan-loading-screen-prevalence
- Apple HIG, Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple, WWDC21 *Discoverable design*: https://developer.apple.com/videos/play/wwdc2021/10126/
- Apple, App Review Guidelines (3.1.2, 5.1.1): https://developer.apple.com/app-store/review/guidelines/
- Apple, Auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
- Apple, WWDC24 *Swift enhancements in Vision* (`RecognizeTextRequest`): https://developer.apple.com/videos/play/wwdc2024/10163/
- INEGI, ENIGH 2024 press release: https://www.inegi.org.mx/contenidos/saladeprensa/boletines/2025/enigh/ENIGH2024_RR.pdf
- Profeco, Quién es Quién en los Precios: https://qqp.profeco.gob.mx/ · Sep 2026 basket comparison (via Los Noticieristas): https://losnoticieristas.com/mananera/2026/10/donde-sale-mas-barata-la-canasta-basica-profeco-revela-precios-y-diferencias-de-hasta-186-pesos-1142198/
