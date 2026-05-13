# Environmental-Security-Project-Wildfire-PM2.5-Violent-Conflict-in-the-U.S.
This project evaluates the influence of increasing wildfire activity on levels of PM2.5 and violent conflict within the United States. Linear regression with fixed effects are ran in R, and a cleaned and aggregated dataset by county-month is provided.

To test this theory, I constructed a county-month dataset combining NASA FIRMS wildfire detections, PM2.5 air quality data, and ACLED political violence event data from 2018 to 2023. The project evaluates multiple direct relationships: wildfire activity and PM2.5, PM2.5 and violent conflict, and wildfire activity and violent conflict. It then tests whether PM2.5 mediates the relationship between wildfire activity and conflict. This approach of linking all three variables in a single empirical framework allows me to better understand direct and indirect pathways linking environmental stressors to human behavior. This project ultimately aims to contribute to ongoing debates in environmental security by clarifying whether and how climate-driven disasters like wildfires translate into social instability beyond their immediate physical destruction.

Main Research Question
- Does higher wildfire activity, measured by fire radiative power, increase violent conflict in U.S. county-months, and is this relationship mediated by PM2.5 air pollution?
Subquestions:
- Does higher wildfire activity increase PM2.5 concentrations within a county-month?
- Are higher PM2.5 concentrations associated with higher levels of violent conflict? 
- Does the relationship between wildfire activity and violent conflict become weaker once PM2.5 is included in the model?

From published literature (linked below), there is evidence that supports me to test this causal chain:
Increased Wildfire Activity → Increased PM2.5 → Increased Violent conflict
H1: Higher wildfire activity is associated with higher PM2.5 concentrations. 
H2: Higher PM2.5 concentrations are associated with higher levels of violent conflict.
H3: Higher wildfire activity is associated with higher levels of violent conflict.
H4: Higher wildfire activity will be associated with an increase in PM2.5 levels; next, an increase in PM2.5 will be associated with an increase in violent conflict. 

My empirical approach uses my county-month panel dataset. Below, i is an index for the counties and t is an index for the months. This structure allows me to compare the data across counties and over time. As described before, I am testing these four linear regression models to test each step of my proposed causal chain: wildfire activity → PM2.5 → violent conflict:

The first model tests whether higher wildfire activity is associated with worse air quality:
H1: PM2.5it = β0 + β1 * FRPit + ϵit​ + αi + δt

The second model tests whether higher PM2.5 concentrations are associated with higher levels of violent conflict:
H2: Conflictit = β0 + β1 * PM2.5it + ϵit​​ + αi + δt

The third model tests the direct relationship between wildfire activity and violent conflict:
H3: Conflictit = β0 + β1 * FRPit + ϵi​t​ + αi + δt

The fourth model tests the mediator by including both wildfire activity and PM2.5 in the same model:
H4: Conflictit = β0 + β1 * FRPit + β2 * PM2.5it​ + ϵi​t + αi + δt
