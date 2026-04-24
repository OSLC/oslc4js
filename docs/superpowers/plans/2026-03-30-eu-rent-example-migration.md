# EU-Rent Example Migration — Replace SolarTech with AI-Driven BMM Spec Example

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded SolarTech example with an AI-driven workflow that populates EU-Rent from the actual BMM 1.3 specification PDF, demonstrating the Define-Instantiate-Activate pattern authentically.

**Architecture:** Remove `load-solartech.sh` and SolarTech-specific `.http` test data. Replace testing files with generic OSLC API smoke tests that use EU-Rent as the ServiceProvider name but contain only minimal test data (not the full example). Update README and presentation to document the AI-driven workflow where Claude reads the BMM 1.3 spec PDF and creates EU-Rent resources via MCP.

**Source document:** The OMG BMM 1.3 specification (`bmm-server/docs/BMM-formal-15-05-19.pdf`) uses EU-Rent — a fictitious European car rental company — as its running example throughout all sections and in Annex C. The spec contains concrete examples of every BMM concept type: Vision, Goals, Objectives, Mission, Strategies, Tactics, Business Policies, Business Rules, External/Internal Influencers, Assessments (SWOT), Potential Impacts (Risks/Rewards), and a detailed reaction-to-influencers narrative in section 8.5.8.

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Delete | `bmm-server/testing/load-solartech.sh` | Remove hardcoded data loader |
| Delete | `bmm-server/testing/03-create-ends.http` | Remove SolarTech-specific test data |
| Delete | `bmm-server/testing/04-create-means.http` | Remove SolarTech-specific test data |
| Delete | `bmm-server/testing/05-create-influencers-assessments.http` | Remove SolarTech-specific test data |
| Delete | `bmm-server/testing/06-create-organization.http` | Remove SolarTech-specific test data |
| Delete | `bmm-server/testing/07-link-resources.http` | Remove SolarTech-specific link templates |
| Modify | `bmm-server/testing/02-create-service-provider.http` | Change to EU-Rent, add generic smoke test |
| Modify | `bmm-server/testing/08-query-resources.http` | Change `solartech` to `eu-rent` |
| Modify | `bmm-server/README.md` | Replace SolarTech documentation with EU-Rent AI-driven workflow |
| Modify | `docs/Define-Instantiate-Activate-Presentation.md` | Replace SolarTech references with EU-Rent |
| Modify | `docs/Define-Instantiate-Activate.md` | Minor: no SolarTech references but verify consistency |

---

### Task 1: Delete SolarTech-specific files

**Files:**
- Delete: `bmm-server/testing/load-solartech.sh`
- Delete: `bmm-server/testing/03-create-ends.http`
- Delete: `bmm-server/testing/04-create-means.http`
- Delete: `bmm-server/testing/05-create-influencers-assessments.http`
- Delete: `bmm-server/testing/06-create-organization.http`
- Delete: `bmm-server/testing/07-link-resources.http`

- [ ] **Step 1: Delete the files**

```bash
cd /Users/jamsden/Developer/OSLC/oslc4js
git rm bmm-server/testing/load-solartech.sh
git rm bmm-server/testing/03-create-ends.http
git rm bmm-server/testing/04-create-means.http
git rm bmm-server/testing/05-create-influencers-assessments.http
git rm bmm-server/testing/06-create-organization.http
git rm bmm-server/testing/07-link-resources.http
```

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor(bmm-server): remove SolarTech hardcoded example data

The SolarTech example was AI-generated content that did not come from the
BMM 1.3 specification. Remove it in preparation for an AI-driven workflow
that populates EU-Rent examples directly from the spec."
```

---

### Task 2: Update testing files for EU-Rent

**Files:**
- Modify: `bmm-server/testing/02-create-service-provider.http`
- Modify: `bmm-server/testing/08-query-resources.http`

- [ ] **Step 1: Update `02-create-service-provider.http`**

Replace SolarTech with EU-Rent. Keep it as a minimal smoke test — just create the ServiceProvider and verify it exists. No domain-specific example data.

```http
###############################################################################
# 02-create-service-provider.http — Create a ServiceProvider for an enterprise
#
# Creates an EU-Rent ServiceProvider as the container for BMM resources.
# The actual EU-Rent BMM resources are populated by an AI assistant reading
# the BMM 1.3 specification (see README.md for the AI-driven workflow).
###############################################################################

@baseUrl = http://localhost:3005

### Create "EU-Rent" enterprise
POST {{baseUrl}}/oslc
Content-Type: text/turtle
Slug: eu-rent

@prefix dcterms: <http://purl.org/dc/terms/> .
<> dcterms:title "EU-Rent" ;
   dcterms:description "Business Motivation Model for EU-Rent, a European car rental company. Based on the running example in the OMG BMM 1.3 specification." .

### Verify the catalog now contains the ServiceProvider
GET {{baseUrl}}/oslc
Accept: text/turtle

### Read the ServiceProvider
GET {{baseUrl}}/oslc/eu-rent
Accept: text/turtle
```

- [ ] **Step 2: Update `08-query-resources.http`**

Change the `@sp` variable from `solartech` to `eu-rent`. The query templates themselves are generic and don't need content changes.

Replace line 8: `@sp = solartech` with `@sp = eu-rent`

- [ ] **Step 3: Commit**

```bash
git add bmm-server/testing/02-create-service-provider.http bmm-server/testing/08-query-resources.http
git commit -m "refactor(bmm-server): update testing files for EU-Rent ServiceProvider"
```

---

### Task 3: Update README.md

**Files:**
- Modify: `bmm-server/README.md`

This is the largest change. The README currently has:
- Line 11-15: Define/Instantiate/Activate summary referencing SolarTech
- Lines 103-118: "Example: SolarTech Inc." section with table of `.http` files
- Lines 141-164: "AI-Driven Population from Documents" section
- Lines 166-244: "Example Prompts" section with SolarTech-specific prompts

- [ ] **Step 1: Update the Define/Instantiate/Activate summary (lines 11-15)**

Replace the SolarTech reference in the Instantiate bullet. Change:
```
38 linked SolarTech resources are created via MCP tool calls.
```
To describe the AI-driven EU-Rent workflow:
```
An AI assistant reads the BMM 1.3 specification and populates the EU-Rent example via MCP tool calls.
```

- [ ] **Step 2: Replace "Example: SolarTech Inc." section (lines 103-118)**

Replace with a new section documenting the AI-driven EU-Rent workflow:

**Section title:** `## Example: EU-Rent (from BMM 1.3 Specification)`

**Content should explain:**
- EU-Rent is the running example in the OMG BMM 1.3 specification (Annex C provides background)
- The spec PDF is included at `docs/BMM-formal-15-05-19.pdf`
- To populate the example, connect an AI assistant to the MCP endpoint and ask it to read the spec
- The `testing/` folder contains `.http` files for verifying the OSLC API (catalog, service provider creation, queries) but the domain data is populated by the AI
- A table showing what the AI creates from the spec (Vision, Goals, Objectives, Mission, Strategies, Tactics, Policies, Rules, Influencers, Assessments, Impacts — all from the actual spec examples)

- [ ] **Step 3: Update "AI-Driven Population from Documents" section (lines 141-164)**

Update the example prompt from:
```
"Read the BMM 1.3 specification and create all the example artifacts..."
```
To:
```
"Read the BMM 1.3 specification at docs/BMM-formal-15-05-19.pdf and create all the EU-Rent example artifacts and relationships described in the document."
```

Remove any reference to the `load-solartech.sh` script.

- [ ] **Step 4: Update "Example Prompts" section (lines 166-244)**

Replace all SolarTech-specific prompts with EU-Rent prompts drawn from the actual spec content. Key categories:

**Populating the model:**
- "Read the BMM 1.3 specification at docs/BMM-formal-15-05-19.pdf and create all the EU-Rent example artifacts and relationships described in the document."

**Exploring the model:**
- "What is EU-Rent's Vision?"
- "List all of EU-Rent's Goals and the Objectives that quantify each one."
- "What Strategies does EU-Rent have, and which Goals does each Strategy channel efforts toward?"
- "Show me the complete Ends hierarchy — Vision, Goals, and Objectives — as an outline."
- "What Tactics implement the car purchase and disposal Strategy?"

**Analysis and insight:**
- "Which Goals have no Strategies channeling efforts toward them?"
- "What External Influencers has EU-Rent identified, and what Assessments have been made about each one?"
- "Trace the chain from the budget airlines Threat through its Assessment to the affected Goals. What Strategies address this threat?"
- "Which Business Policies govern which Courses of Action? Are there any ungoverned Strategies or Tactics?"
- "What Business Rules enforce the 'minimize depreciation' Business Policy?"

**Impact analysis (based on spec section 8.5.8):**
- "EU-Rent is considering expanding into Eastern Europe. Trace the Influencers, Assessments, and Potential Impacts that support this decision."
- "Two smaller competitors have merged. How does this Influencer affect EU-Rent's Goals and Strategies?"
- "What Risks has EU-Rent identified for its premium brand positioning strategy?"

**Modification and extension:**
- "Add a new Goal: 'Expand into Eastern European markets' with an Objective to establish operations in 5 Eastern European countries by end of next year. Link the Goal to the Vision."
- "Create an Assessment for the budget airlines Influencer that identifies it as a Threat to the premium airport positioning Strategy."

- [ ] **Step 5: Update the impact analysis example response (lines 192-233)**

Remove the SolarTech tax credit example response and replace with an EU-Rent example based on the spec's section 8.5.8 narrative (EU-Rent's reaction to influencers regarding premium brand positioning and car depreciation).

- [ ] **Step 6: Commit**

```bash
git add bmm-server/README.md
git commit -m "docs(bmm-server): replace SolarTech with AI-driven EU-Rent example from BMM spec

EU-Rent is the running example in the OMG BMM 1.3 specification. The example
is now populated by an AI assistant reading the actual spec PDF via MCP,
demonstrating the Define-Instantiate-Activate pattern authentically."
```

---

### Task 4: Update the presentation

**Files:**
- Modify: `docs/Define-Instantiate-Activate-Presentation.md`

- [ ] **Step 1: Update Layer 2 Example slide (SolarTech table)**

Replace the SolarTech slide with EU-Rent. The table should show what the BMM 1.3 spec contains:

| BMM Concept | EU-Rent Examples in Spec |
|-------------|------------------------|
| Vision | 1 (premium brand car rental) |
| Goals | 4 (premium brand, customer service, well-maintained cars, vehicle availability) |
| Objectives | 4 (A C Nielsen ratings, customer satisfaction survey, breakdown rate) |
| Mission | 1 (car rental across Europe and North America) |
| Strategies | 3+ (nationwide operation, car purchase/disposal, rewards scheme) |
| Tactics | 5+ (encourage extensions, outsource maintenance, standard specs, equalize usage, comply with maintenance) |
| Business Policies | 5+ (minimize depreciation, guarantee payments, no exports, etc.) |
| Business Rules | 6+ (match spec, lowest mileage, driver's license, service scheduling, etc.) |
| Influencers | 28+ (competitors, customers, regulations, technology, assumptions, habits, etc.) |
| Assessments | 6+ (SWOT: strengths, weaknesses, opportunities, threats) |
| Potential Impacts | 5+ (risks and rewards) |

- [ ] **Step 2: Update the "AI Transforms Layer 2" slide**

Change the SME quote from:
```
"Read the BMM 1.3 spec and create all SolarTech example artifacts."
```
To:
```
"Read the BMM 1.3 specification and create all the EU-Rent example artifacts and relationships described in the document."
```

Remove the "38 resources automatically" claim — the number comes from reading the actual spec.

- [ ] **Step 3: Update the "BMM Server: A Complete Working Example" slide**

Replace "SolarTech example with 38 resources" with "EU-Rent example from BMM 1.3 spec, populated by AI reading the PDF."

Update the "Try it" section:
```bash
# Start Fuseki, then:
cd bmm-server && npm start
# AI prompt: "Read the BMM 1.3 specification at
#   docs/BMM-formal-15-05-19.pdf and create all the EU-Rent
#   example artifacts and relationships."
```

- [ ] **Step 4: Update any remaining SolarTech references**

Search the presentation for any remaining "SolarTech" or "solartech" references and replace with EU-Rent equivalents.

- [ ] **Step 5: Commit**

```bash
git add docs/Define-Instantiate-Activate-Presentation.md
git commit -m "docs: update presentation to use EU-Rent example from BMM spec"
```

---

### Task 5: Verify consistency across documents

- [ ] **Step 1: Search for any remaining SolarTech references**

```bash
grep -ri "solartech\|solar.tech" --include="*.md" --include="*.http" --include="*.sh" .
```

Expected: no results.

- [ ] **Step 2: Verify the testing files are self-consistent**

Check that `01-catalog.http`, `02-create-service-provider.http`, and `08-query-resources.http` all use consistent URLs (`eu-rent`).

- [ ] **Step 3: Verify the BMM spec PDF is present**

```bash
ls -la bmm-server/docs/BMM-formal-15-05-19.pdf
```

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "chore(bmm-server): fix any remaining SolarTech references"
```
