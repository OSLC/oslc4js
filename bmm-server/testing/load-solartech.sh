#!/usr/bin/env bash
#
# load-solartech.sh — Create the SolarTech BMM example with full links
# via the embedded MCP endpoint.
#
# Usage: ./load-solartech.sh
# Requires: bmm-server running at http://localhost:3005
#

set -euo pipefail

BASE="http://localhost:3005"
CATALOG="$BASE/oslc"

# ── Create ServiceProvider ─────────────────────────────────────

echo "Creating ServiceProvider..."
curl -sf -o /dev/null -w "" -X POST "$CATALOG" \
  -H "Content-Type: text/turtle" \
  -H "Slug: solartech" \
  --data-raw '@prefix dcterms: <http://purl.org/dc/terms/> .
<> dcterms:title "SolarTech Inc." ;
   dcterms:description "Business Motivation Model for SolarTech Inc., a renewable energy technology company." .'
echo "  ServiceProvider: solartech"

sleep 3  # Wait for MCP rediscovery

# ── Initialize MCP session ─────────────────────────────────────

INIT=$(curl -s -D /tmp/mcp_h -X POST "$BASE/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"loader","version":"1.0"}}}')
SID=$(grep -i 'mcp-session-id' /tmp/mcp_h | awk -F': ' '{print $2}' | tr -d '\r\n')

curl -s -X POST "$BASE/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

echo "MCP session: $SID"

# ── MCP tool helper ────────────────────────────────────────────

ID=10
create() {
  local tool=$1
  local args=$2
  local label=$3

  ID=$((ID + 1))
  local resp=$(curl -s -X POST "$BASE/mcp" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SID" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$ID,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}")

  local uri=$(echo "$resp" | sed -n 's/^data: //p' | node --input-type=module -e "
    import {createInterface} from 'readline';
    let d=''; for await (const l of createInterface({input:process.stdin})) d+=l;
    const j=JSON.parse(d); const t=JSON.parse(j.result.content[0].text);
    process.stdout.write(t.uri||'ERROR');
  " 2>/dev/null)

  echo "  $label -> $uri"
  # Return URI via stdout — caller captures with $()
  echo "$uri"
}

# ── Create resources in dependency order ───────────────────────
# Layer 0: No outgoing links (leaf nodes, influencers, assets, processes)
# Layer 1: Links to Layer 0 (assessments, objectives, tactics, rules)
# Layer 2: Links to Layer 1 (strategies, policies, goals, potential impacts)
# Layer 3: Links to Layer 2 (vision, mission, org units)

echo ""
echo "=== Layer 0: Foundation resources ==="

# Influencers (no outgoing BMM links)
INF_TAX=$(create create_influencers \
  '{"title":"Federal Solar Investment Tax Credit Extension","description":"The US federal government extended the 30% Investment Tax Credit for residential solar installations through 2032 under the Inflation Reduction Act.","influencerCategory":"Regulation"}' \
  "Influencer: Tax Credit" | tail -1)

INF_COMP=$(create create_influencers \
  '{"title":"Low-Cost Import Competition","description":"Aggressive pricing from overseas manufacturers is compressing margins across the domestic solar panel market, with some imports priced 40% below domestic production cost.","influencerCategory":"Competition"}' \
  "Influencer: Import Competition" | tail -1)

INF_LABOR=$(create create_influencers \
  '{"title":"Certified Installer Shortage","description":"Industry-wide shortage of NABCEP-certified solar installers is constraining installation capacity and extending lead times to 8+ weeks.","influencerCategory":"Resource"}' \
  "Influencer: Labor Shortage" | tail -1)

INF_TECH=$(create create_influencers \
  '{"title":"Perovskite Tandem Cell Breakthrough","description":"SolarTech R&D lab has achieved a 31.2% efficiency perovskite-silicon tandem cell in laboratory conditions, ahead of competitors.","influencerCategory":"Technology"}' \
  "Influencer: Perovskite" | tail -1)

# Assets (no outgoing BMM links)
ASSET_MFG=$(create create_assets \
  '{"title":"Austin Manufacturing Campus","description":"500MW annual capacity solar panel manufacturing facility including cell fabrication, module assembly, and electroluminescence testing."}' \
  "Asset: Manufacturing" | tail -1)

ASSET_PAT=$(create create_assets \
  '{"title":"Perovskite Tandem Cell Patent Portfolio","description":"12 granted patents and 8 pending applications covering perovskite-silicon tandem cell architecture, encapsulation, and manufacturing."}' \
  "Asset: Patents" | tail -1)

ASSET_MON=$(create create_assets \
  '{"title":"SolarWatch Monitoring Platform","description":"Cloud-based IoT platform monitoring 85,000 installed systems in real-time with energy production analytics and fault detection."}' \
  "Asset: Monitoring" | tail -1)

echo ""
echo "=== Layer 1: Assessments, Business Rules, Business Processes ==="

# Assessments (link to influencers)
ASMT_TAX=$(create create_assessments \
  "{\"title\":\"Tax Credit Drives Residential Demand Growth\",\"description\":\"The ITC extension is projected to increase residential solar adoption by 25-30% through 2030, creating a significant window for market share capture.\",\"assessesInfluencer\":\"$INF_TAX\"}" \
  "Assessment: Tax Credit" | tail -1)

ASMT_IMP=$(create create_assessments \
  "{\"title\":\"Import Pricing Threatens Margin Sustainability\",\"description\":\"Current import pricing is below variable manufacturing cost for standard panels. Without vertical integration or tariff protection, commodity panel margins will erode within 18 months.\",\"assessesInfluencer\":\"$INF_COMP\"}" \
  "Assessment: Import Threat" | tail -1)

ASMT_LAB=$(create create_assessments \
  "{\"title\":\"Installer Shortage Constrains Growth and Quality\",\"description\":\"The certified installer shortage limits both installation volume and quality consistency, threatening NPS targets and market share growth.\",\"assessesInfluencer\":\"$INF_LABOR\"}" \
  "Assessment: Labor" | tail -1)

# Business Rules (no outgoing links for now)
RULE_WARR=$(create create_business_rules \
  '{"title":"Warranty Claim 48-Hour Response","description":"All warranty claims must receive an initial response within 48 hours and a technician dispatch within 5 business days.","enforcementLevel":"Strictly enforced"}' \
  "Rule: Warranty Response" | tail -1)

RULE_EFF=$(create create_business_rules \
  '{"title":"Minimum Panel Efficiency 22%","description":"No solar panel may be released for sale with a rated efficiency below 22%. Panels below this threshold must be reworked or scrapped.","enforcementLevel":"Strictly enforced"}' \
  "Rule: Efficiency Floor" | tail -1)

RULE_DATA=$(create create_business_rules \
  '{"title":"Customer Data Retained Maximum 7 Years","description":"Customer personal data shall be purged within 7 years after the end of the warranty period unless the customer opts in to extended monitoring.","enforcementLevel":"Override with explanation"}' \
  "Rule: Data Retention" | tail -1)

# Business Processes (link to assets via realizesAsset, link to rules via governedByBusinessRule)
PROC_DEV=$(create create_business_processes \
  "{\"title\":\"Product Development Lifecycle\",\"description\":\"End-to-end process from research concept through prototype, IEC certification testing, manufacturing transfer, and product launch.\",\"realizesAsset\":\"$ASSET_PAT\",\"governedByBusinessRule\":\"$RULE_EFF\"}" \
  "Process: Product Dev" | tail -1)

PROC_INST=$(create create_business_processes \
  "{\"title\":\"Order-to-Installation\",\"description\":\"Customer inquiry, site assessment, system design, permitting, installation, inspection, and grid connection.\",\"realizesAsset\":\"$ASSET_MON\"}" \
  "Process: Order-Install" | tail -1)

PROC_WARR=$(create create_business_processes \
  "{\"title\":\"Warranty Claim Resolution\",\"description\":\"Receive claim, triage severity, dispatch technician, diagnose issue, repair or replace, close claim.\",\"realizesAsset\":\"$ASSET_MON\",\"governedByBusinessRule\":\"$RULE_WARR\"}" \
  "Process: Warranty" | tail -1)

echo ""
echo "=== Layer 2: Objectives, Tactics, Policies, Potential Impacts ==="

# Objectives (no outgoing links yet — will be linked from Goals)
OBJ_MKT=$(create create_objectives \
  '{"title":"Achieve 15% Residential Market Share","description":"Capture 15% of the North American residential solar panel market by installed capacity.","targetDate":"2027-12-31","measureOfProgress":"Quarterly installed capacity as percentage of total market"}' \
  "Objective: Market Share" | tail -1)

OBJ_NPS=$(create create_objectives \
  '{"title":"Achieve NPS Score of 70+","description":"Achieve and sustain a Net Promoter Score of 70 or above across all customer segments.","targetDate":"2026-06-30","measureOfProgress":"Monthly NPS survey results"}' \
  "Objective: NPS" | tail -1)

OBJ_COST=$(create create_objectives \
  '{"title":"Reduce Manufacturing Cost per Watt by 20%","description":"Reduce the fully-loaded manufacturing cost per watt by 20% from the 2024 baseline.","targetDate":"2027-06-30","measureOfProgress":"Quarterly cost-per-watt from manufacturing ERP"}' \
  "Objective: Cost" | tail -1)

# Tactics (link to strategies later, link to rules via effectsEnforcementOfBusinessRule)
TACT_LAB=$(create create_tactics \
  "{\"title\":\"Expand Perovskite Research Lab\",\"description\":\"Establish a dedicated perovskite tandem cell research facility with 30 researchers, targeting a 33% efficiency prototype by 2026.\"}" \
  "Tactic: Perovskite Lab" | tail -1)

TACT_CERT=$(create create_tactics \
  "{\"title\":\"Certified Installer Network\",\"description\":\"Build a network of certified installation partners with mandatory training, quality audits, and customer satisfaction scoring.\"}" \
  "Tactic: Installer Network" | tail -1)

TACT_WAF=$(create create_tactics \
  "{\"title\":\"Build Silicon Wafer Production Facility\",\"description\":\"Construct a 2GW silicon wafer production facility in Arizona to reduce raw material costs by 35%.\"}" \
  "Tactic: Wafer Plant" | tail -1)

# Business Policies (link to rules via basedOnBusinessRule, link to processes via governsBusinessProcess)
POL_QUAL=$(create create_business_policies \
  "{\"title\":\"Product Quality Standards\",\"description\":\"All products shall meet or exceed IEC 61215 and IEC 61730 certification standards. No product may ship without passing full electroluminescence inspection.\",\"basedOnBusinessRule\":\"$RULE_EFF\",\"governsBusinessProcess\":\"$PROC_DEV\"}" \
  "Policy: Quality" | tail -1)

POL_DATA=$(create create_business_policies \
  "{\"title\":\"Customer Data Protection\",\"description\":\"Customer energy production data, financial information, and personal details shall be protected in accordance with applicable privacy regulations.\",\"basedOnBusinessRule\":\"$RULE_DATA\",\"governsBusinessProcess\":\"$PROC_INST\"}" \
  "Policy: Data Protection" | tail -1)

# Potential Impacts (link to assessments via identifiedByAssessment)
IMP_WINDOW=$(create create_potential_impacts \
  "{\"title\":\"5-Year Market Expansion Window\",\"description\":\"The ITC extension creates a 5-year window of accelerated residential solar demand. Companies that scale fastest will capture durable market share.\",\"identifiedByAssessment\":\"$ASMT_TAX\"}" \
  "Impact: Market Window" | tail -1)

IMP_MARGIN=$(create create_potential_impacts \
  "{\"title\":\"Commodity Panel Margin Collapse\",\"description\":\"If competing on price in the commodity segment, gross margins will fall below 10%, providing impetus for differentiation through innovation.\",\"identifiedByAssessment\":\"$ASMT_IMP\"}" \
  "Impact: Margin Collapse" | tail -1)

echo ""
echo "=== Layer 3: Goals, Strategies, Mission, Vision, Org Units ==="

# Goals (link to objectives via quantifiedByObjective, link to vision later)
GOAL_MKT=$(create create_goals \
  "{\"title\":\"Grow Market Share\",\"description\":\"Increase market share in the residential solar panel market to become a top-three supplier by installed capacity.\",\"quantifiedByObjective\":\"$OBJ_MKT\"}" \
  "Goal: Market Share" | tail -1)

GOAL_SAT=$(create create_goals \
  "{\"title\":\"Maximize Customer Satisfaction\",\"description\":\"Achieve and sustain industry-leading customer satisfaction through product reliability, installation quality, and post-sale support.\",\"quantifiedByObjective\":\"$OBJ_NPS\"}" \
  "Goal: Satisfaction" | tail -1)

GOAL_EFF=$(create create_goals \
  "{\"title\":\"Improve Operational Efficiency\",\"description\":\"Reduce manufacturing costs and streamline the supply chain to offer competitive pricing without compromising quality.\",\"quantifiedByObjective\":\"$OBJ_COST\"}" \
  "Goal: Efficiency" | tail -1)

# Strategies (link to goals via channelsEffortsTowardGoal, link to tactics via includesStrategy is wrong - tactics implementStrategy)
STRAT_INNOV=$(create create_strategies \
  "{\"title\":\"Product Innovation Leadership\",\"description\":\"Invest in R&D to develop next-generation solar cells with industry-leading efficiency ratings, differentiating through technology.\",\"channelsEffortsTowardGoal\":\"$GOAL_MKT\",\"enablesEnd\":\"$GOAL_MKT\"}" \
  "Strategy: Innovation" | tail -1)

STRAT_CX=$(create create_strategies \
  "{\"title\":\"End-to-End Customer Experience\",\"description\":\"Own the entire customer journey from initial consultation through 25-year warranty, building long-term relationships.\",\"channelsEffortsTowardGoal\":\"$GOAL_SAT\",\"enablesEnd\":\"$GOAL_SAT\"}" \
  "Strategy: Customer Experience" | tail -1)

STRAT_SC=$(create create_strategies \
  "{\"title\":\"Vertical Supply Chain Integration\",\"description\":\"Reduce dependency on external suppliers by vertically integrating key components to control costs and quality.\",\"channelsEffortsTowardGoal\":\"$GOAL_EFF\",\"enablesEnd\":\"$GOAL_EFF\"}" \
  "Strategy: Supply Chain" | tail -1)

# Mission (link to vision later)
MISSION=$(create create_missions \
  '{"title":"Deliver Affordable Solar Energy Solutions","description":"Design, manufacture, and install high-efficiency solar energy systems for residential and commercial customers, providing end-to-end service from site assessment through installation, monitoring, and maintenance."}' \
  "Mission" | tail -1)

# Vision (link to mission and goals)
VISION=$(create create_visions \
  "{\"title\":\"Leading Renewable Energy Provider\",\"description\":\"To be the leading provider of affordable, high-efficiency solar energy solutions for residential and commercial markets worldwide.\",\"amplifiedByMission\":\"$MISSION\",\"madeOperativeByGoal\":[\"$GOAL_MKT\",\"$GOAL_SAT\",\"$GOAL_EFF\"]}" \
  "Vision" | tail -1)

# Organization Units (link to ends, means, influencers, assessments, processes)
ORG_EXEC=$(create create_organization_units \
  "{\"title\":\"Executive Leadership Team\",\"description\":\"CEO, COO, CFO, CTO — responsible for the enterprise Vision, Mission, and overall Strategy.\",\"isResponsibleForEnd\":\"$VISION\",\"establishesMeans\":\"$MISSION\",\"makesAssessment\":\"$ASMT_TAX\"}" \
  "OrgUnit: Executive" | tail -1)

ORG_RD=$(create create_organization_units \
  "{\"title\":\"Research and Development\",\"description\":\"Solar cell research, product development, and prototype testing. Responsible for the Product Innovation strategy.\",\"establishesMeans\":\"$STRAT_INNOV\",\"recognizesInfluencer\":\"$INF_TECH\",\"definedByBusinessProcess\":\"$PROC_DEV\"}" \
  "OrgUnit: R&D" | tail -1)

ORG_MFG=$(create create_organization_units \
  "{\"title\":\"Manufacturing Operations\",\"description\":\"Panel production, quality assurance, and supply chain management.\",\"isResponsibleForEnd\":\"$GOAL_EFF\",\"establishesMeans\":\"$STRAT_SC\",\"definedByBusinessProcess\":\"$PROC_DEV\"}" \
  "OrgUnit: Manufacturing" | tail -1)

ORG_CUS=$(create create_organization_units \
  "{\"title\":\"Customer Operations\",\"description\":\"Sales, installation coordination, warranty service, and the certified installer network.\",\"isResponsibleForEnd\":\"$GOAL_SAT\",\"establishesMeans\":\"$STRAT_CX\",\"recognizesInfluencer\":\"$INF_LABOR\",\"makesAssessment\":\"$ASMT_LAB\",\"definedByBusinessProcess\":\"$PROC_INST\"}" \
  "OrgUnit: Customer Ops" | tail -1)

echo ""
echo "=== Verifying ==="
COUNT=$(curl -s "$BASE/oslc/solartech/resources" -H "Accept: text/turtle" | grep -o 'res:mn[a-z0-9]*' | wc -l | tr -d ' ')
echo "Total resources: $COUNT"
echo ""
echo "Browse at $BASE/"
