#!/usr/bin/env bash
#
# populate-eurent.sh — Populate the EU-Rent BMM example in bmm-server
# via MCP tool calls (Streamable HTTP transport).
#
# Data sourced from OMG Business Motivation Model 1.3 specification
# (formal/2015-05-19), Chapter 8 examples and Annex C (EU-Rent
# background). Creates 72 linked resources: Vision, Goals, Objectives,
# Mission, Strategies, Tactics, Business Policies, Business Rules,
# Influencers (external + internal), Assessments (SWOT), Potential
# Impacts, Business Processes, Assets, and Organization Units.
#
# If the "eu-rent" ServiceProvider doesn't yet exist, the script
# creates it via the create_service_provider MCP tool. bmm-server's
# embedded MCP endpoint auto-rediscovers the catalog after a new
# ServiceProvider is created, so the per-type create_* tools (e.g.,
# create_visions, create_goals, etc.) become available within the
# same MCP session — no session restart needed. This is the same
# refresh mechanism an MCP client with listChanged support would
# observe; for clients that don't honor listChanged (e.g., Claude
# Desktop), the script here is a scripted workaround.
#
# Usage:  ./testing/populate-eurent.sh
# Prereq: bmm-server running at http://localhost:3005; node available
#         on PATH for JSON parsing.
#
# This is the same flow an AI assistant exercises when asked to
# populate EU-Rent from the BMM 1.3 spec via MCP; this script is a
# scripted, deterministic equivalent useful for development and CI.

set -u
BASE="http://localhost:3005"
MCP="$BASE/mcp"

# ── Initialize MCP session ─────────────────────────────────────
curl -sf -D /tmp/eur_h.txt -X POST "$MCP" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"eurent-populator","version":"1.0"}}}' > /dev/null
SID=$(grep -i "mcp-session-id" /tmp/eur_h.txt | awk -F': ' '{print $2}' | tr -d '\r\n')
echo "MCP session: $SID"

curl -sf -X POST "$MCP" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' > /dev/null

# ── Helper: call a tool, echo the new resource URI ─────────────
# Usage: create <tool_name> <json_args>
CALL_ID=10
create() {
  local tool=$1
  local args=$2
  local label=$3
  CALL_ID=$((CALL_ID + 1))
  local body
  body=$(printf '{"jsonrpc":"2.0","id":%d,"method":"tools/call","params":{"name":"%s","arguments":%s}}' "$CALL_ID" "$tool" "$args")
  local resp
  resp=$(curl -sf -X POST "$MCP" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -H "Mcp-Session-Id: $SID" \
    -d "$body")
  local uri
  # Extract URI from SSE response: keep only the data line's JSON payload.
  uri=$(printf '%s' "$resp" | sed -n 's/^data: //p' | node --input-type=module -e '
    import {createInterface} from "readline";
    let d="";
    for await (const l of createInterface({input:process.stdin})) d += l;
    try {
      const j = JSON.parse(d);
      const t = JSON.parse(j.result.content[0].text);
      process.stdout.write(t.uri || "");
    } catch (e) {
      process.stderr.write("PARSE ERROR: " + e.message + "\nRAW: " + d.slice(0,300) + "\n");
    }
  ' 2>/dev/null)
  if [ -z "$uri" ]; then
    echo "FAILED: $label" >&2
    echo "Response: $resp" >&2
    return 1
  fi
  echo "  $label -> $uri" >&2
  printf '%s' "$uri"
}

# Shorthand helper that captures a URI into a named shell variable
# for use in later link fields.
# Usage: mk VAR_NAME <tool> <args> <label>
mk() {
  local var=$1; shift
  local uri
  uri=$(create "$@")
  eval "$var=\"$uri\""
}

echo ""
echo "============================================================"
echo "EU-Rent BMM Example Population (from OMG BMM 1.3 spec)"
echo "============================================================"

# ── Ensure the eu-rent ServiceProvider exists ──────────────────
# Idempotent: if the ServiceProvider already exists, the server
# returns a 409 conflict in the tool result; we treat that as "OK,
# already there" and continue. On a successful creation the server
# auto-rediscovers, which adds the per-type create_* and query_*
# tools to the handler map used by this same MCP session.
SP_URI="$BASE/oslc/eu-rent"
echo "── Ensuring ServiceProvider ──────────────────────────────"
SP_RESP=$(curl -sf -X POST "$MCP" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SID" \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"create_service_provider","arguments":{"title":"EU-Rent","slug":"eu-rent","description":"EU-Rent BMM example from OMG BMM 1.3 specification (Annex C). Fictitious European car rental company used throughout the spec to illustrate Ends, Means, Influencers, Assessments, and Directives."}}}')
if printf '%s' "$SP_RESP" | grep -q "already exists"; then
  echo "  ServiceProvider already exists: $SP_URI"
elif printf '%s' "$SP_RESP" | grep -q '"uri"'; then
  echo "  ServiceProvider created: $SP_URI"
else
  echo "  WARNING: unexpected create_service_provider response:" >&2
  printf '%s\n' "$SP_RESP" | head -5 >&2
fi

# ============================================================
# Layer 0: Influencers (no outgoing BMM links)
# ============================================================
echo ""
echo "── External Influencers ──────────────────────────────────"

mk INF_COMP_MERGE create_influencers '{
  "title": "Competitor merger in European countries",
  "description": "Two smaller competitors have merged and the joint enterprise is now bigger than EU-Rent in several European countries.",
  "influencerCategory": "Competitor"
}' "External Influencer: Competitor merger"

mk INF_PREMIUM_BRANDS create_influencers '{
  "title": "Premium brand competitors (Hertz, Avis)",
  "description": "Premium brand car rental companies such as Hertz and Avis have a high quality, value for money image and can charge higher rates.",
  "influencerCategory": "Competitor"
}' "External Influencer: Premium brands"

mk INF_BUDGET_AIRLINES create_influencers '{
  "title": "Budget airlines",
  "description": "Budget airlines offering low-cost, short-haul flights, often to secondary airports.",
  "influencerCategory": "Competitor"
}' "External Influencer: Budget airlines"

mk INF_BIZ_CUSTOMERS create_influencers '{
  "title": "Business vs. personal customer segments",
  "description": "EU-Rent primary target is business customers, but it recognizes the need to appeal also to personal renters.",
  "influencerCategory": "Customer"
}' "External Influencer: Customer segments"

mk INF_MARKET_RESEARCH create_influencers '{
  "title": "Customer perception: premium vs cheap-and-cheerful",
  "description": "Market research: customers accept premium rates for premium brands; tend to see on-airport as premium and off-airport as cheap.",
  "influencerCategory": "Customer"
}' "External Influencer: Market research"

mk INF_CITY_PARKING create_influencers '{
  "title": "City-center parking limitations",
  "description": "Car parking and storage in city centers is limited and expensive.",
  "influencerCategory": "Environment"
}' "External Influencer: City parking"

mk INF_EE_GROWTH create_influencers '{
  "title": "Eastern Europe car rental market growth",
  "description": "The car rental market in Eastern Europe growing year-on-year by at least 5% per year.",
  "influencerCategory": "Environment"
}' "External Influencer: Eastern Europe growth"

mk INF_ONAIRPORT create_influencers '{
  "title": "On-airport competitive environment",
  "description": "All on-airport car rental companies offer similar types of car, and are physically lined up in a row. There is very little room for maneuver against competitors on product, service, or price.",
  "influencerCategory": "Environment"
}' "External Influencer: On-airport environment"

mk INF_ECLEASE create_influencers '{
  "title": "EC-Lease financing partner",
  "description": "EC-Lease finances cars for EU-Rent at preferential terms within several EC countries in return for a share of EU-Rent profits.",
  "influencerCategory": "Partner"
}' "External Influencer: EC-Lease"

mk INF_REGULATIONS create_influencers '{
  "title": "National laws and regulations",
  "description": "Laws and regulations in each country of operation for driver license and insurance, roadworthiness of cars, and protection of customer personal information.",
  "influencerCategory": "Regulation"
}' "External Influencer: Regulations"

mk INF_CAR_MANUFACTURERS create_influencers '{
  "title": "Car manufacturers",
  "description": "Car manufacturers provide car models and options offered, prices, contract terms, and conditions.",
  "influencerCategory": "Supplier"
}' "External Influencer: Car manufacturers"

mk INF_INSURERS create_influencers '{
  "title": "Insurers",
  "description": "Insurers provide cover offered, options, premiums.",
  "influencerCategory": "Supplier"
}' "External Influencer: Insurers"

mk INF_TRACKING_TECH create_influencers '{
  "title": "Vehicle identification and tracking systems",
  "description": "Vehicle identification and tracking systems.",
  "influencerCategory": "Technology"
}' "External Influencer: Vehicle tracking"

mk INF_INTERNET_RES create_influencers '{
  "title": "Internet self-service reservations",
  "description": "Internet support for self service rental reservations.",
  "influencerCategory": "Technology"
}' "External Influencer: Internet reservations"

echo ""
echo "── Internal Influencers ──────────────────────────────────"

mk INF_EXPANSION create_influencers '{
  "title": "Business expansion expectation",
  "description": "EU-Rent needs to expand its business year on year.",
  "influencerCategory": "Assumption"
}' "Internal Influencer: Business expansion"

mk INF_LOYALTY create_influencers '{
  "title": "Loyalty rewards assumption",
  "description": "A loyalty rewards program is essential for attracting business customers.",
  "influencerCategory": "Assumption"
}' "Internal Influencer: Loyalty program"

mk INF_PROMOTE_WITHIN create_influencers '{
  "title": "Managers promoted from within",
  "description": "Managers are generally promoted from within the company.",
  "influencerCategory": "Habit"
}' "Internal Influencer: Promote from within"

mk INF_BRANCH_CLUSTER create_influencers '{
  "title": "Branch clustering around cities",
  "description": "Rental branches are clustered in and around major cities, with large branches at airports and city centers, medium-sized branches in suburbs and nearby towns, and small agencies in hotels and travel agents premises.",
  "influencerCategory": "Infrastructure"
}' "Internal Influencer: Branch clustering"

mk INF_EE_PRIORITY create_influencers '{
  "title": "Eastern Europe expansion priority",
  "description": "The EU-Rent board has decided to give priority to Eastern Europe for business expansion in the next three years.",
  "influencerCategory": "Management Prerogative"
}' "Internal Influencer: Eastern Europe priority"

mk INF_ENV_FRIENDLY create_influencers '{
  "title": "Environment-friendly corporate value",
  "description": "EU-Rent is environment-friendly. All the car models it offers for rental have good fuel economy and low emissions.",
  "influencerCategory": "Corporate Value"
}' "Internal Influencer: Environment-friendly"

# ============================================================
# Layer 0 continued: Assets
# ============================================================
echo ""
echo "── Assets ────────────────────────────────────────────────"

mk ASSET_FLEET create_assets '{
  "title": "Vehicle rental fleet",
  "description": "Cars owned by local areas, available to the rental branches in the area. Includes popular models from reputable manufacturers with low mileage, environment-friendly options, and low-cost maintenance."
}' "Asset: Vehicle fleet"

mk ASSET_BRANCHES create_assets '{
  "title": "Rental branch network",
  "description": "Large branches at airports and city centers, medium-sized branches in suburbs and nearby towns, small agencies in hotels and travel agents premises."
}' "Asset: Branch network"

mk ASSET_INET_SW create_assets '{
  "title": "Internet rentals software platform",
  "description": "Software platform supporting individual rentals via the internet. Has few facilities to support corporate rental agreements."
}' "Asset: Internet rentals software"

mk ASSET_BRAND create_assets '{
  "title": "EU-Rent brand",
  "description": "The EU-Rent brand — positioned as a premium car rental provider with quality, service, and value for money."
}' "Asset: EU-Rent brand"

# ============================================================
# Layer 0: Business Processes (no outgoing BMM links to new
# types; realizes Assets and governedByBusinessRule set later)
# ============================================================
echo ""
echo "── Business Processes ────────────────────────────────────"

mk PROC_RESERVATION create_business_processes "$(cat <<JSON
{
  "title": "Rental reservation process",
  "description": "Advance rental bookings accepted by phone, internet, or in person at any EU-Rent branch.",
  "realizes": "$ASSET_INET_SW"
}
JSON
)" "Process: Reservation"

mk PROC_PICKUP create_business_processes "$(cat <<JSON
{
  "title": "Car pickup and return",
  "description": "In-branch handling of customer arrival, car assignment (lowest mileage in group), documentation, and car return including odometer/service checks.",
  "realizes": "$ASSET_FLEET"
}
JSON
)" "Process: Pickup & return"

mk PROC_MAINTENANCE create_business_processes "$(cat <<JSON
{
  "title": "Vehicle maintenance",
  "description": "Scheduled maintenance per manufacturer schedule, with small branches outsourcing maintenance and larger branches performing it in-house.",
  "realizes": "$ASSET_FLEET"
}
JSON
)" "Process: Maintenance"

mk PROC_PURCHASE create_business_processes "$(cat <<JSON
{
  "title": "Car purchase and disposal",
  "description": "National-level guidance on which models to buy, mix and numbers, when to dispose by mileage and age, and phasing of purchasing and delivery.",
  "realizes": "$ASSET_FLEET"
}
JSON
)" "Process: Car purchase/disposal"

# ============================================================
# Layer 1: Objectives (no outgoing BMM links - Goals will
# point to them via quantifiedBy)
# ============================================================
echo ""
echo "── Objectives ────────────────────────────────────────────"

mk OBJ_NIELSEN_EC create_objectives '{
  "title": "A C Nielsen top 6 in EC countries by year-end",
  "description": "By end of current year, be rated by A C Nielsen in the top 6 car rental companies in each operating country within the European Community.",
  "measureOfProgress": "A C Nielsen quarterly rankings"
}' "Objective: Nielsen top 6 (EC)"

mk OBJ_NIELSEN_OTHER create_objectives '{
  "title": "A C Nielsen top 9 in non-EC countries by year-end",
  "description": "By end of current year, be rated by A C Nielsen in the top 9 car rental companies in all other operating countries.",
  "measureOfProgress": "A C Nielsen quarterly rankings"
}' "Objective: Nielsen top 9 (non-EC)"

mk OBJ_SATISFACTION create_objectives '{
  "title": "85% customer satisfaction score by year-end",
  "description": "By end of current year, to score 85% on EU-Rent quarterly customer satisfaction survey.",
  "measureOfProgress": "Quarterly customer satisfaction survey score"
}' "Objective: Customer satisfaction 85%"

mk OBJ_BREAKDOWN create_objectives '{
  "title": "Less than 1% mechanical breakdown rate (Q4)",
  "description": "During 4th quarter of current year, no more than 1% of rentals need the car to be replaced because of mechanical breakdown (excluding accidents).",
  "measureOfProgress": "Percentage of rentals requiring replacement car due to mechanical breakdown"
}' "Objective: < 1% breakdown"

# ============================================================
# Layer 2: Goals (link to Objectives via quantifiedBy)
# ============================================================
echo ""
echo "── Goals ─────────────────────────────────────────────────"

mk GOAL_PREMIUM create_goals "$(cat <<JSON
{
  "title": "Be a premium brand car rental company",
  "description": "To be a premium brand car rental company, positioned alongside companies such as Hertz and Avis.",
  "quantifiedBy": ["$OBJ_NIELSEN_EC", "$OBJ_NIELSEN_OTHER"]
}
JSON
)" "Goal: Premium brand positioning"

mk GOAL_SERVICE create_goals "$(cat <<JSON
{
  "title": "Provide industry-leading customer service",
  "description": "To provide industry-leading customer service.",
  "quantifiedBy": "$OBJ_SATISFACTION"
}
JSON
)" "Goal: Industry-leading service"

mk GOAL_MAINTAINED create_goals "$(cat <<JSON
{
  "title": "Provide well-maintained cars",
  "description": "To provide well-maintained cars.",
  "quantifiedBy": "$OBJ_BREAKDOWN"
}
JSON
)" "Goal: Well-maintained cars"

mk GOAL_AVAILABILITY create_goals '{
  "title": "Vehicles available when and where expected",
  "description": "To have vehicles available for rental when and where customers expect them."
}' "Goal: Vehicle availability"

# ============================================================
# Mission (no outgoing BMM links in our current shapes)
# ============================================================
echo ""
echo "── Mission ───────────────────────────────────────────────"

mk MISSION create_missions '{
  "title": "Car rental service across Europe and North America",
  "description": "Provide car rental service across Europe and North America for both business and personal customers."
}' "Mission"

# ============================================================
# Vision (amplifiedBy -> Mission, madeOperativeBy -> Goals)
# ============================================================
echo ""
echo "── Vision ────────────────────────────────────────────────"

mk VISION create_visions "$(cat <<JSON
{
  "title": "Be the car rental brand of choice for business users",
  "description": "Be the car rental brand of choice for business users in the countries in which we operate.",
  "amplifiedBy": "$MISSION",
  "madeOperativeBy": ["$GOAL_PREMIUM", "$GOAL_SERVICE", "$GOAL_MAINTAINED", "$GOAL_AVAILABILITY"]
}
JSON
)" "Vision"

# ============================================================
# Layer 3: Strategies (channelsEffortsToward Vision/Goals,
# enablesEnd -> End)
# ============================================================
echo ""
echo "── Strategies ────────────────────────────────────────────"

mk STRAT_NATIONWIDE create_strategies "$(cat <<JSON
{
  "title": "Nationwide on-airport head-to-head competition",
  "description": "Operate nation-wide in each country of operation, focusing on major airports, competing head-to-head, on-airport, with other premium car rental companies.",
  "channelsEffortsToward": ["$VISION", "$GOAL_PREMIUM"],
  "enablesEnd": "$GOAL_PREMIUM"
}
JSON
)" "Strategy: Nationwide on-airport"

mk STRAT_CAR_PURCHASE create_strategies "$(cat <<JSON
{
  "title": "Manage car purchase and disposal at local area level",
  "description": "Manage car purchase and disposal at local area level, with national (operating company) guidance covering: what models may be bought from which manufacturers; overall numbers and mix of models; when to dispose of cars, by mileage and age; phasing of purchasing and delivery.",
  "channelsEffortsToward": "$GOAL_MAINTAINED",
  "enablesEnd": ["$GOAL_MAINTAINED", "$GOAL_AVAILABILITY"]
}
JSON
)" "Strategy: Car purchase management"

mk STRAT_REWARDS create_strategies "$(cat <<JSON
{
  "title": "Outsource loyalty rewards to third-party scheme",
  "description": "Join an established rewards scheme run by a third party (i.e., outsource rather than building own scheme).",
  "channelsEffortsToward": "$GOAL_SERVICE",
  "enablesEnd": "$GOAL_SERVICE"
}
JSON
)" "Strategy: Rewards scheme"

# ============================================================
# Layer 4: Tactics (implements -> Strategy, enablesEnd -> End,
# effectsEnforcementOfBusinessRule -> Rule added after Rules
# exist via update_resource)
# ============================================================
echo ""
echo "── Tactics ───────────────────────────────────────────────"

mk TACTIC_EXTEND create_tactics "$(cat <<JSON
{
  "title": "Encourage rental extensions",
  "description": "Encourage rental extensions to maximize utilization of existing rentals.",
  "implements": "$STRAT_NATIONWIDE"
}
JSON
)" "Tactic: Encourage rental extensions"

mk TACTIC_OUTSOURCE_MAINT create_tactics "$(cat <<JSON
{
  "title": "Outsource maintenance for small branches",
  "description": "Outsource maintenance for small branches where in-house maintenance is not cost-effective.",
  "implements": "$STRAT_CAR_PURCHASE"
}
JSON
)" "Tactic: Outsource maintenance"

mk TACTIC_STANDARD_SPEC create_tactics "$(cat <<JSON
{
  "title": "Create standard specifications of car models",
  "description": "Create standard specifications of car models, selecting from options offered by the manufacturers. This is a trade-off between rentable and high residual value for sales.",
  "implements": "$STRAT_CAR_PURCHASE"
}
JSON
)" "Tactic: Standard car specs"

mk TACTIC_EQUALIZE create_tactics "$(cat <<JSON
{
  "title": "Equalize car usage across rentals",
  "description": "Equalize use of cars across rentals so that mileage is similar for cars of the same car group and age.",
  "implements": "$STRAT_CAR_PURCHASE"
}
JSON
)" "Tactic: Equalize car usage"

mk TACTIC_MAINT_SCHED create_tactics "$(cat <<JSON
{
  "title": "Comply with manufacturers' maintenance schedules",
  "description": "Comply with car manufacturers maintenance schedules to maintain residual value and reliability.",
  "implements": "$STRAT_CAR_PURCHASE"
}
JSON
)" "Tactic: Comply with maintenance schedules"

# ============================================================
# Business Policies (governs -> CourseOfAction,
# governsProcess -> BusinessProcess)
# ============================================================
echo ""
echo "── Business Policies ─────────────────────────────────────"

mk POL_DEPRECIATION create_business_policies "$(cat <<JSON
{
  "title": "Minimize depreciation of rental cars",
  "description": "Depreciation of rental cars must be minimized.",
  "governs": "$STRAT_CAR_PURCHASE"
}
JSON
)" "Policy: Minimize depreciation"

mk POL_PAYMENT create_business_policies '{
  "title": "Rental payments guaranteed in advance",
  "description": "Rental payments must be guaranteed in advance."
}' "Policy: Payment guarantee"

mk POL_NO_EXPORT create_business_policies '{
  "title": "Rental cars must not be exported",
  "description": "Rental cars must not be exported."
}' "Policy: No car export"

mk POL_PICKUP_LAW create_business_policies "$(cat <<JSON
{
  "title": "Rental contracts under pickup country law",
  "description": "Rental contracts are made under the law of the country in which the pick-up branch is located.",
  "governsProcess": "$PROC_RESERVATION"
}
JSON
)" "Policy: Pickup country law"

mk POL_COMPLIANCE create_business_policies '{
  "title": "Comply with laws and regulations",
  "description": "Rentals must comply with relevant laws and regulations of all countries to be visited."
}' "Policy: Regulatory compliance"

# ============================================================
# Business Rules (basedOn -> Policy, governs -> CourseOfAction,
# enforcedByBusinessProcess -> Process)
# ============================================================
echo ""
echo "── Business Rules ────────────────────────────────────────"

mk RULE_STD_SPEC create_business_rules "$(cat <<JSON
{
  "title": "Car must match standard specification",
  "description": "Each Car purchased must match the standard specification of its Car Model.",
  "basedOn": "$POL_DEPRECIATION",
  "enforcedByBusinessProcess": "$PROC_PURCHASE",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Match standard spec"

mk RULE_LOWEST_MILEAGE create_business_rules "$(cat <<JSON
{
  "title": "Assign lowest-mileage car in group",
  "description": "The Car assigned to a Rental must be: at the time of assignment, of the available Cars in the requested Car Group, the one with the lowest mileage.",
  "basedOn": "$POL_DEPRECIATION",
  "enforcedByBusinessProcess": "$PROC_PICKUP",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Lowest mileage"

mk RULE_DRIVER_LICENSE create_business_rules "$(cat <<JSON
{
  "title": "Valid driver license required",
  "description": "A customer must present a valid driver license in order to rent a EU-Rent vehicle.",
  "enforcedByBusinessProcess": "$PROC_PICKUP",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Driver license required"

mk RULE_SERVICE_200 create_business_rules "$(cat <<JSON
{
  "title": "Service scheduling by odometer threshold",
  "description": "A Car whose odometer reading is greater than (next service mileage - 200) must be scheduled for service.",
  "basedOn": "$POL_DEPRECIATION",
  "enforcedByBusinessProcess": "$PROC_MAINTENANCE",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Service scheduling"

mk RULE_EXTENSION_500 create_business_rules "$(cat <<JSON
{
  "title": "Extension requires car exchange if near service",
  "description": "The rental of a car whose odometer reading is greater than (next service mileage - 500) may be extended only if the car is exchanged at a EU-Rent branch.",
  "enforcedByBusinessProcess": "$PROC_PICKUP",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Extension requires exchange"

mk RULE_OVER_21 create_business_rules "$(cat <<JSON
{
  "title": "Every driver must be over 21",
  "description": "Every driver on a rental must be over 21 years old.",
  "enforcedByBusinessProcess": "$PROC_PICKUP",
  "enforcementLevel": "strictly enforced"
}
JSON
)" "Rule: Minimum age 21"

# ============================================================
# Potential Impacts (providesImpetusFor -> Directive,
# isRisk/RewardForEnd/Means)
# ============================================================
echo ""
echo "── Potential Impacts ─────────────────────────────────────"

mk IMP_CUSTOMER_LOSS create_potential_impacts "$(cat <<JSON
{
  "title": "Risk: 15% customer loss if not positioned as premium",
  "description": "Failure to position EU-Rent as a premium brand risks loss of an estimated 15% of current customers without replacement by new customers.",
  "isRiskForEnd": "$GOAL_PREMIUM"
}
JSON
)" "Impact: 15% customer loss risk"

mk IMP_WEEKEND_IDLE create_potential_impacts "$(cat <<JSON
{
  "title": "Risk: Weekend fleet idle and undercut by cheap competition",
  "description": "Many unrented cars at weekends, with rates undercut by the cheap and cheerful competition.",
  "isRiskForEnd": "$GOAL_PREMIUM"
}
JSON
)" "Impact: Weekend idle risk"

mk IMP_PENALTIES create_potential_impacts '{
  "title": "Risk: Scandinavian emissions non-compliance penalties",
  "description": "Severe financial penalties for failure to comply with stringent emission control requirements in Scandinavia that apply to any EU-Rent car that might be driven there."
}' "Impact: Emissions penalties"

mk IMP_RATE_INCREASE create_potential_impacts "$(cat <<JSON
{
  "title": "Reward: 12% rate increase from premium positioning",
  "description": "Market acceptance would support an average increase of 12% on rental rates.",
  "isRewardForEnd": "$GOAL_PREMIUM"
}
JSON
)" "Impact: 12% rate increase reward"

mk IMP_DEPR_REDUCTION create_potential_impacts "$(cat <<JSON
{
  "title": "Reward: 3% depreciation cost reduction",
  "description": "Reduction of depreciation costs by 3%.",
  "providesImpetusFor": "$POL_DEPRECIATION"
}
JSON
)" "Impact: 3% depreciation reduction"

# ============================================================
# Assessments (assesses -> Influencer,
# identifiesPotentialImpact -> PotentialImpact,
# affectsAchievementOfEnd/EmploymentOfMeans)
# ============================================================
echo ""
echo "── Assessments (SWOT) ────────────────────────────────────"

mk ASMT_STRENGTH_GEO create_assessments "$(cat <<JSON
{
  "title": "Strength: Geographical distribution of branches",
  "description": "Infrastructure strength — the geographical distribution of branches enables appeal to business customers.",
  "assesses": "$INF_BRANCH_CLUSTER",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Strength",
  "affectsAchievementOfEnd": "$GOAL_PREMIUM"
}
JSON
)" "Assessment: Strength - Geography"

mk ASMT_WEAK_CORP_SW create_assessments "$(cat <<JSON
{
  "title": "Weakness: Internet software limited for corporate agreements",
  "description": "The software for internet rentals has few facilities for self-service of corporate rental agreements.",
  "assesses": "$INF_INTERNET_RES",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Weakness",
  "affectsAchievementOfEnd": "$GOAL_SERVICE"
}
JSON
)" "Assessment: Weakness - Corporate SW"

mk ASMT_WEAK_STAFF create_assessments "$(cat <<JSON
{
  "title": "Weakness: High branch counter staff turnover",
  "description": "High turnover of branch counter staff frequently causes shortage of experienced staff in branches, which can cause delays in dealing with exceptions and problems.",
  "assesses": "$INF_PROMOTE_WITHIN",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Weakness",
  "affectsAchievementOfEnd": "$GOAL_SERVICE"
}
JSON
)" "Assessment: Weakness - Staff turnover"

mk ASMT_OPP_PREMIUM create_assessments "$(cat <<JSON
{
  "title": "Opportunity: Room in premium brand market",
  "description": "EU-Rent thinks there is room for competition in the premium brand car rental market.",
  "assesses": "$INF_PREMIUM_BRANDS",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Opportunity",
  "identifiesPotentialImpact": ["$IMP_RATE_INCREASE", "$IMP_CUSTOMER_LOSS"],
  "affectsAchievementOfEnd": "$GOAL_PREMIUM"
}
JSON
)" "Assessment: Opportunity - Premium market"

mk ASMT_OPP_DEPR create_assessments "$(cat <<JSON
{
  "title": "Opportunity: Improved depreciation management",
  "description": "Improved management of depreciation would reduce costs. Depreciation on cars between purchase and sale at end of rental life is a critical factor in financial success.",
  "assesses": "$INF_ONAIRPORT",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Opportunity",
  "identifiesPotentialImpact": "$IMP_DEPR_REDUCTION"
}
JSON
)" "Assessment: Opportunity - Depreciation"

mk ASMT_THREAT_AIRLINES create_assessments "$(cat <<JSON
{
  "title": "Threat: Budget airlines to secondary airports",
  "description": "Budget airlines provide low-cost flights to major cities, but using secondary airports where EU-Rent does not have branches.",
  "assesses": "$INF_BUDGET_AIRLINES",
  "assessmentCategory": "http://www.omg.org/spec/BMM#InfluencerCategoryType-Threat",
  "affectsAchievementOfEnd": "$GOAL_PREMIUM"
}
JSON
)" "Assessment: Threat - Budget airlines"

# ============================================================
# Organization Units
# ============================================================
echo ""
echo "── Organization Units ────────────────────────────────────"

mk ORG_BOARD create_organization_units "$(cat <<JSON
{
  "title": "EU-Rent Board",
  "description": "Corporate board with strategic authority, including decisions about expansion priorities (e.g., Eastern Europe).",
  "isResponsibleFor": "$VISION",
  "establishes": "$MISSION",
  "recognizes": "$INF_EE_GROWTH",
  "makesAssessment": "$ASMT_OPP_PREMIUM"
}
JSON
)" "OrgUnit: Board"

mk ORG_OPCO create_organization_units "$(cat <<JSON
{
  "title": "Operating Company (per country)",
  "description": "National operating company responsible for strategy within a country of operation, including car purchase/disposal guidance and customer service standards.",
  "establishes": ["$STRAT_CAR_PURCHASE", "$STRAT_NATIONWIDE"],
  "recognizes": "$INF_REGULATIONS"
}
JSON
)" "OrgUnit: Operating Company"

mk ORG_LOCAL_AREA create_organization_units "$(cat <<JSON
{
  "title": "Local Area",
  "description": "Owns the pool of cars available to rental branches in the area. Manages car purchase and disposal at local level within national guidance.",
  "definedBy": "$PROC_PURCHASE",
  "isResponsibleFor": "$GOAL_MAINTAINED"
}
JSON
)" "OrgUnit: Local Area"

mk ORG_BRANCH create_organization_units "$(cat <<JSON
{
  "title": "Rental Branch",
  "description": "Customer-facing location handling rental reservations, pickups, returns, and exceptions. Allocation (capacity, not actual cars) from the local area pool.",
  "definedBy": ["$PROC_RESERVATION", "$PROC_PICKUP"],
  "isResponsibleFor": "$GOAL_AVAILABILITY"
}
JSON
)" "OrgUnit: Rental Branch"

echo ""
echo "============================================================"
echo "Population complete. Counting resources per type..."
echo "============================================================"
curl -s "$BASE/oslc/eu-rent/query" -H "Accept: text/turtle" | \
  grep -oE "a bmm:[A-Z][a-zA-Z]+" | sort | uniq -c
echo ""
echo "Browse at $BASE/"
