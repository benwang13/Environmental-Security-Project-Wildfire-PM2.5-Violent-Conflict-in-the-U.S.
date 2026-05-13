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
- H1: PM2.5it = β0 + β1 * FRPit + ϵit​ + αi + δt

The second model tests whether higher PM2.5 concentrations are associated with higher levels of violent conflict:
- H2: Conflictit = β0 + β1 * PM2.5it + ϵit​​ + αi + δt

The third model tests the direct relationship between wildfire activity and violent conflict:
- H3: Conflictit = β0 + β1 * FRPit + ϵi​t​ + αi + δt

The fourth model tests the mediator by including both wildfire activity and PM2.5 in the same model:
- H4: Conflictit = β0 + β1 * FRPit + β2 * PM2.5it​ + ϵi​t + αi + δt

Literature Works Cited:
- Burke, Marshall, Solomon M. Hsiang, and Edward Miguel. “Climate and Conflict.” Annual Review of Economics, vol. 7, 2015, pp. 577–617. https://doi.org/10.1146/annurev-economics-080614-115430.
- Burkhardt, Jesse, et al. “The Effect of Pollution on Crime: Evidence from Data on Particulate Matter and Ozone.” Journal of Environmental Economics and Management, vol. 98, 2019, article 102267. https://doi.org/10.1016/j.jeem.2019.102267.
- California Air Resources Board. Climate Vulnerability Metric: Unequal Climate Impacts in the State of California. Sept. 2022, https://ww2.arb.ca.gov/sites/default/files/2022-11/2022-sp-appendix-k-climate-vulnerability-metric.pdf.
- California Department of Forestry and Fire Protection. Top 20 Most Destructive California Wildfires. CAL FIRE, https://34c031f8-c9fd-4018-8c5a-4159cdff6b0d-cdn-endpoint.azureedge.net/-/media/calfire-website/our-impact/fire-statistics/top-20-destructive-ca-wildfires.pdf.
- Hennighausen, Hannah, and Alexander James. “Catastrophic Fires, Human Displacement, and Real Estate Prices in California.” Journal of Housing Economics, vol. 66, 2024, article 102023. https://doi.org/10.1016/j.jhe.2024.102023.
- Herrnstadt, Evan, Anthony Heyes, Erich Muehlegger, and Soodeh Saberian. “Air Pollution as a Cause of Violent Crime: Evidence from Los Angeles and Chicago.” 2019. https://erichmuehlegger.com/Working%20Papers/crime_LA_november_2019.pdf.
- Kircheis, Lion. “Wildfire Smoke Increases Assaults: Evidence from Seattle.” Environmental Research Letters, vol. 21, no. 4, 2026. https://doi.org/10.1088/1748-9326/ae436c.
- Lee, Goeun, and Seunghyun Lee. “The Impact of Wildfire Smoke Exposure on Crime.” Environmental and Resource Economics, vol. 89, no. 1, 2026, article 5. https://doi.org/10.1007/s10640-025-01053-2.
- Marlier, Miriam E., et al. “Exposure of Agricultural Workers in California to Wildfire Smoke under Past and Future Climate Conditions.” Environmental Research Letters, vol. 17, no. 9, 2022, article 094045. https://doi.org/10.1088/1748-9326/ac8c58.
- NASA. “Wildfires and Climate Change.” NASA Science, 30 Jan. 2025, https://science.nasa.gov/earth/explore/wildfires-and-climate-change/.
- Roberts, Gareth, and Martin J. Wooster. “Global Impact of Landscape Fire Emissions on Surface Level PM2.5 Concentrations, Air Quality Exposure and Population Mortality.” Atmospheric Environment, vol. 252, 2021, article 118210. https://doi.org/10.1016/j.atmosenv.2021.118210.
- Zhang, Min, et al. “Wildfire Smoke PM2.5 and Mortality Rate in the Contiguous United States: A Causal Modeling Study.” Science Advances, vol. 12, no. 6, 2026, pp. 1–11. https://doi.org/10.1126/sciadv.adw5890.
Data Sources
- Armed Conflict Location & Event Data Project. ACLED Conflict Data Export Tool. ACLED, https://acleddata.com/conflict-data/data-export-tool/.
- Atmospheric Composition Analysis Group. Surface PM2.5, V5.GL.05.02 Monthly HybridPM2.5 North America. Washington University in St. Louis, https://sites.wustl.edu/acag/datasets/surface-pm2-5/.
- NASA FIRMS. Fire Information for Resource Management System Active Fire Data. NASA Earthdata, https://firms.modaps.eosdis.nasa.gov/.
- United States Census Bureau. Cartographic Boundary Files. U.S. Census Bureau, https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.html.
