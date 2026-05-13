#install.packages("tidyverse")
#install.packages("dplyr")
#install.packages("lubridate")
#install.packages("readr")
#install.packages("here")
#install.packages("haven")
#install.packages("fixest")
#install.packages("ncdf4")
#install.packages("raster")
#install.packages("exactextractr")
#install.packages("stringr")
#install.packages("sf")
#install.packages("ggplot2")
#install.packages("patchwork")
library(tidyverse)
library(dplyr)
library(lubridate)
library(here)
library(ncdf4)
library(raster)
library(exactextractr)
library(stringr)
library(readr)
library(sf)

#set up directories (match it with your own file structure)
wd_project     <- "/Users/benwa/Desktop/Env_Security" 
wd_code_R <- here(wd_project,"02_code/01_R") # where's your R code?
wd_data <- here(wd_project,"01_data") # where's your data (in general)?
wd_data_in_raw <- here(wd_data,"01_raw") # where specifically is your data - in the raw data folder
wd_data_in_proc <- here(wd_data,"02_processed") # where specifically is your data - in the processed data folder
wd_data_out <- here(wd_data,"02_processed") # if you make/modify a dataset that you want to save for later, where will you put it?
wd_tabfig <- here(wd_project,"03_tablesfigures") # if you want to save tables or figures, where will you put them?

#FIRST, READ IN WILDFIRE DATA
fires <- read_csv(
  here(wd_data_in_raw, "WildfireData.csv"))
head(fires)

#filtering data by the columns that we care about, all the other ones are not necessary for this project
fires_slim <- fires %>% dplyr::select(latitude, longitude, brightness, acq_date, frp)
head(fires_slim)

#use lubridate for year/month/date aggregation
fires_slim <- fires_slim %>% dplyr::mutate(month = lubridate::month(acq_date))
#confirm that it is working, months should change between these two results below
view(head(fires_slim, 1000)) #1000 lines
view(fires_slim[30000:31000,]) 

head(fires_slim)
#reading shp file into an R object, sf object, data frame
fires.shp <- st_read(here(wd_data_in_raw,"DL_FIRE_SV-C2_743424"),
                          layer = "fire_archive_SV-C2_743424")
class(fires.shp) #see what it is
fires.shp
fires_slim.shp <- fires.shp %>% dplyr::select(LATITUDE, LONGITUDE, BRIGHTNESS, ACQ_DATE, FRP)
fires_slim.shp <- fires_slim.shp %>% dplyr::mutate(month = lubridate::month(ACQ_DATE))
head(fires_slim.shp)

#NOW IMPORTING CENSUS BORDER DATA, SO WE CAN ACTUALLY AGGREGATE OUR DATA BY COUNTIES
#find U.S. shp file counties census.gov, take the cb_2018_500k one
counties <- st_read(here(wd_data_in_raw, "cb_2018_us_county_500k"),
                    layer = "cb_2018_us_county_500k")
counties <- st_transform(counties, crs = st_crs(fires_slim.shp))
#st_join matches each fire point to the county polygon it falls within
fires_with_county <- st_join(fires_slim.shp, counties["GEOID"], join = st_within)
#Drop fires that didn't fall inside any county
fires_with_county <- fires_with_county %>% filter(!is.na(GEOID))
#Aggregate Fire Data by County-Month
#first getting year tho
fires_with_county <- fires_with_county %>%
  mutate(year  = lubridate::year(ACQ_DATE),
         month = lubridate::month(ACQ_DATE))
fire_county_month <- fires_with_county %>%
  st_drop_geometry() %>%                       
  group_by(GEOID, year, month) %>%
  summarise(
    fire_count   = n(),                          #number of fire detections
    frp_mean     = mean(FRP, na.rm = TRUE),      #avg fire intensity
    frp_sum      = sum(FRP,  na.rm = TRUE),      #total fire intensity
    brightness_mean = mean(BRIGHTNESS, na.rm = TRUE),
    .groups = "drop"
  )

#Now that the data has county month, I will not import the ACLED violent conflict data
acled <- read_csv(here(wd_data_in_raw, "acled_us.csv"))
#Convert to sf object using lat/lon columns
acled_sf <- acled %>%
  filter(!is.na(longitude), !is.na(latitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
#Match CRS to counties
acled_sf <- st_transform(acled_sf, crs = st_crs(counties))

#Spatially Join ACLED Points → Counties
acled_with_county <- st_join(acled_sf, counties["GEOID"], join = st_within)
acled_with_county <- acled_with_county %>% filter(!is.na(GEOID))
view(acled_with_county)
acled_with_county <- acled_with_county %>%
  mutate(event_date = lubridate::ymd(event_date),   #ACLED ships as DD-Month-YYYY
         year  = lubridate::year(event_date),
         month = lubridate::month(event_date)) %>%
  filter(event_date >= as.Date("2018-01-01") & event_date < as.Date("2023-01-01"))

#aggregating the data by county-month
acled_county_month <- acled_with_county %>%
  st_drop_geometry() %>%
  group_by(GEOID, year, month) %>%
  summarise(
    conflict_count   = n(),                            #total events
    fatalities_sum   = sum(fatalities, na.rm = TRUE),  #total fatalities
    .groups = "drop"
  )

head(acled_county_month)

#Merge Fire + Conflict into One Panel Dataset by building the full grid of every county × every month in the study period
#We use the counties shapefile as the authority on which GEOIDs should exist, rather than deriving GEOIDs from the fire data (which only has months WITH fires)
#This guarantees every county appears for all 60 months, even if it had no fires
full_grid <- expand.grid(
  GEOID = counties %>% st_drop_geometry() %>% pull(GEOID),  #all ~3,144 U.S. counties
  year  = 2018:2022,                                         #5 years
  month = 1:12,                                              #12 months each
  stringsAsFactors = FALSE                                   #keep GEOID as character
)

#now im doing a left join fire data onto the full grid
#rows in full_grid with no matching fire data get NA, which we then fill with 0
#(NA fire_count means no fires detected that month — correctly represented as 0)
panel <- full_grid %>%
  left_join(fire_county_month, by = c("GEOID", "year", "month")) %>%
  
  #Left join conflict data onto the same grid
  left_join(acled_county_month, by = c("GEOID", "year", "month")) %>%
  #Replace all NAs with 0 for count/sum columns
  #NA here simply means "no events detected" where im not truly missing data, but instead of Na, I want it to be 0 so I can still do analysis on it
  mutate(across(c(fire_count, frp_mean, frp_sum, brightness_mean,
                  conflict_count, fatalities_sum),
                ~ replace_na(.x, 0)))

#I will do a quick sanity check: should be n_counties × 60 (3,144 × 60= 188,640)
nrow(panel)

#Add a county name by merging in the counties reference table
county_ref <- counties %>%
  st_drop_geometry() %>%
  dplyr::select(GEOID, STATEFP, COUNTYFP, NAME)

panel <- panel %>% left_join(county_ref, by = "GEOID")
glimpse(panel)
write_csv(panel, here(wd_data_out, "panel_county_month.csv"))

#NOW INTRODUCING PM2.5 DATA AND ADDING IT TO MY CURRENT DATASET:
pm25_dir   <- here(wd_data_in_raw, "pm25data")
pm25_files <- list.files(pm25_dir, pattern = "V5GL0502.*\\.nc$", full.names = TRUE)
length(pm25_files)  #Here, i am verifying that the length is 60, as there is one dataset for each month
#so 5 x 12 = 60. If it imports properly, 60 is what it should be.
#The PM2.5 rasters use WGS84 (lat/lon, EPSG:4326)
#We transform counties to match so the spatial extraction lines up correctly
#so We do this ONCE outside the loop so we're not repeating it 60 times
counties_wgs84 <- st_transform(counties, crs = 4326)
#keep only the county identifier column and save it into county_geoids
county_geoids  <- counties_wgs84 %>% st_drop_geometry() %>% dplyr::select(GEOID)
library(ncdf4)
nc_test <- nc_open(pm25_files[1])
print(names(nc_test$var))  #note what this prints — likely "PM25" or "GWRPM25"
nc_close(nc_test)

#Loop over all 60 files and extract mean PM2.5 per county 
#For each file i will:
#- parse the year and month from the filename
#- load the raster layer
#- use exact_extract() to get the mean PM2.5 value inside each county polygon
#- store the result as a small dataframe in a list
pm25_list <- list()   
for (i in seq_along(pm25_files)) {
  fname <- basename(pm25_files[i])   #just the filename, no folder path
  #The filename looks like: V5GL0502.HybridPM25E.NorthAmerica.202208-202208.nc
  #We extract the first 6-digit block before the dash, e.g. "202208"
  #Then split that into year (ex. 2022) and month (ex. 08)
  yyyymm <- str_extract(fname, "\\d{6}(?=-\\d{6})")   #regex: 6 digits before a "-" + 6 digits
  yr     <- as.integer(substr(yyyymm, 1, 4))           #characters 1-4 = year
  mon    <- as.integer(substr(yyyymm, 5, 6))           #characters 5-6 = month
  
  #Skip any files outside 2018-2022 study period
  if (is.na(yr) | yr < 2018 | yr > 2022) next
  
  #Load the NetCDF file as a single raster layer
  #varname should match what nc_test printed in step 3 — change "PM25" if needed
  r <- raster::raster(pm25_files[i], varname = "GWRPM25SIGMA")
  
  #Explicitly set the CRS to WGS84 — some files don't embed it and raster() 
  #will complain or silently misalign without this
  crs(r) <- CRS("+proj=longlat +datum=WGS84")
  
  #exact_extract() computes the mean PM2.5 across all raster pixels that fall
  #within each county polygon. This is more accurate than a centroid approach
  #because it accounts for pixels that partially overlap county boundaries.
  #Returns one numeric value per county, in the same row order as counties_wgs84
  pm25_vals <- exact_extract(r, counties_wgs84, fun = "mean")
  
  #Attach the extracted values back to the GEOID list along with year and month
  pm25_list[[i]] <- county_geoids %>%
    mutate(
      pm25_mean = pm25_vals,   #mean PM2.5 concentration (ug/m3) for this county-month
      year      = yr,
      month     = mon
    )
  
  #Progress message so you can see it's working (60 files takes a few minutes)
  cat("Processed file", i, "of", length(pm25_files), ":", fname, "\n")
}

#Collapse the list of 60 dataframes into one single dataframe
pm25_county_month <- bind_rows(pm25_list)
#Sanity checks
nrow(pm25_county_month)   #should be ~188,640 (3,144 counties × 60 months)
head(pm25_county_month)   #should show GEOID, pm25_mean, year, month

#NOW MERGE PM2.5 TO EXISTING PANEL DATASET: I WILL BE USING LEFTJOIN!
panel <- panel %>%
  left_join(pm25_county_month, by = c("GEOID", "year", "month"))

#Verify the merge worked — pm25_mean column should now appear
#and there should be no NAs unless a county was somehow missing from the rasters
glimpse(panel)
sum(is.na(panel$pm25_mean))   #ideally 0; if not, investigate which GEOIDs are missing

#so all the Nas go away (counties aren't tracked by WashU data i am assuming)
panel <- panel %>% filter(pm25_mean > 0)

#now reordering and filtering the columns i want
panel <- panel %>%
  dplyr::select(
    GEOID,       
    NAME,           
    STATEFP,        
    COUNTYFP,        
    year,   
    month,
    date,
    fire_count,   
    frp_sum,      
    pm25_mean,
    conflict_count,  
    fatalities_sum
  )

panel <- panel %>%
  arrange(GEOID, date, year, month)
panel <- panel %>%
  mutate(date = lubridate::make_date(year, month, 1))  #e.g. 2018-01-01 for Jan 2018

#Re-save with the new column
#Look at the panel to make sure everything looks good! 
write_csv(panel, here(wd_data_out, "final_dataset.csv"))
head(panel)
view(panel)

#START OF THE EMPIRICAL APPROACH/ANALYSIS
#install.packages("knitr")
#install.packages("kableExtra")
library(knitr)
library(kableExtra)

summary_table <- tibble(
  Variable = c("Total FRP", "Average PM2.5", "Violent Conflict Count", "Fire Count", "Fatality Count"),
  Mean = c(
    mean(panel$frp_sum,        na.rm = TRUE),
    mean(panel$pm25_mean,      na.rm = TRUE),
    mean(panel$conflict_count, na.rm = TRUE),
    mean(panel$fire_count,     na.rm = TRUE),
    mean(panel$fatalities_sum, na.rm = TRUE)
  ),
  
  Median = c(
    median(panel$frp_sum,        na.rm = TRUE),
    median(panel$pm25_mean,      na.rm = TRUE),
    median(panel$conflict_count, na.rm = TRUE),
    median(panel$fire_count,     na.rm = TRUE),
    median(panel$fatalities_sum, na.rm = TRUE)
  ),
  
  Min = c(
    min(panel$frp_sum,        na.rm = TRUE),
    min(panel$pm25_mean,      na.rm = TRUE),
    min(panel$conflict_count, na.rm = TRUE),
    min(panel$fire_count,     na.rm = TRUE),
    min(panel$fatalities_sum, na.rm = TRUE)
  ),
  
  Max = c(
    max(panel$frp_sum,        na.rm = TRUE),
    max(panel$pm25_mean,      na.rm = TRUE),
    max(panel$conflict_count, na.rm = TRUE),
    max(panel$fire_count,     na.rm = TRUE),
    max(panel$fatalities_sum, na.rm = TRUE)
  ),
  
  `Standard Deviation` = c(
    sd(panel$frp_sum,        na.rm = TRUE),
    sd(panel$pm25_mean,      na.rm = TRUE),
    sd(panel$conflict_count, na.rm = TRUE),
    sd(panel$fire_count,     na.rm = TRUE),
    sd(panel$fatalities_sum, na.rm = TRUE)
  )
) %>%
  #now round all of our columns to 3 decimal places so it looks clean
  mutate(across(where(is.numeric), ~ round(.x, 3)))
view(summary_table)

#NOW RUN REGRESSION
#install.packages("ggplot2")
#install.packages("patchwork")
#install.packages("modelsummary")
#install.packages("pandoc")
library(fixest)
library(ggplot2)
library(patchwork)
library(modelsummary)
library(pandoc)

#WE HAVE TO SCALE THE VARIABLES, otherwise our regression results will have coefficients of 0.
#I tested this, and the scales are so different, so we need to scale them differently
panel <- panel %>%
  mutate(
    frp_sum_scaled  = frp_sum  / 1000,   #now interpreted as "per 1,000 FRP units"
    pm25_scaled     = pm25_mean           #already in ug/m3, no rescaling needed
  )

#Rerun all models with scaled variables
#H1: Does wildfire activity (FRP) predict PM2.5? 
#Outcome: pm25_mean, Predictor: frp_sum
h1 <- feols(pm25_scaled ~ frp_sum_scaled | GEOID + year^month,
            data  = panel,
            vcov  = "hetero")   #robust standard errors given skewed FRP distribution

#H2: Does PM2.5 predict violent conflict?
#Outcome: conflict_count | Predictor: pm25_mean
h2 <- feols(conflict_count ~ pm25_scaled | GEOID + year^month,
            data  = panel,
            vcov  = "hetero")

#H3: Does wildfire activity directly predict violent conflict?
#Outcome: conflict_count | Predictor: frp_sum
h3 <- feols(conflict_count ~ frp_sum_scaled | GEOID + year^month,
            data  = panel,
            vcov  = "hetero")

#H4: Does PM2.5 mediate the wildfire → conflict relationship? 
#This is the main model with both FRP and PM2.5 included in it
#If β1 on frp_sum shrinks compared to H3, PM2.5 is acting as a mediator
#Outcome: conflict_count, Predictors: frp_sum + pm25_mean
h4 <- feols(conflict_count ~ frp_sum_scaled + pm25_scaled | GEOID + year^month,
            data  = panel,
            vcov  = "hetero")

#H4b: Same as H4 but with fatalities as outcome, just an alternative to H4
h4b <- feols(fatalities_sum ~ frp_sum_scaled + pm25_scaled | GEOID + year^month,
             data  = panel,
             vcov  = "hetero")

coef_names <- c("frp_sum"   = "Total FRP",
                "pm25_mean" = "Mean PM2.5")

#Regression results table with more decimal places
modelsummary(
  models = list("H1: PM2.5"        = h1,
                "H2: Conflict"     = h2,
                "H3: Conflict"     = h3,
                "H4: Conflict"     = h4,
                "H4b: Fatalities"  = h4b),
  coef_map = c("frp_sum_scaled" = "Total FRP (per 1,000 units)",
               "pm25_scaled"    = "Mean PM2.5 (μg/m³)"),
  stars   = TRUE,
  fmt     = 6,             #show 6 decimal places so small coefficients are visible
  gof_map = c("nobs", "r.squared"),
  title   = "Table 3: Regression Results",
  notes   = "Heteroskedasticity-robust standard errors in parentheses. 
             All models include county and year-month fixed effects.
             FRP scaled to per 1,000 units for interpretability."
)


#No we calculate the mediation: how much of the wildfire→conflict effect is explained by PM2.5?
#We compare the β1 coefficient on frp_sum between H3 and H4
beta_h3 <- coef(h3)["frp_sum_scaled"]   #direct effect (no mediator)
beta_h4 <- coef(h4)["frp_sum_scaled"]   #direct effect (with mediator controlled)

#Percent of the effect mediated through PM2.5
pct_mediated <- (beta_h3 - beta_h4) / beta_h3 * 100
pct_mediated

#NOW WE MAKE THE GRAPHS FOR H1-H4
#Set a clean theme for all plots
theme_set(theme_minimal(base_size = 12) +
            theme(plot.title    = element_text(face = "bold", size = 13),
                  plot.subtitle = element_text(size = 10, color = "grey40"),
                  axis.title    = element_text(size = 10)))

#H1 GRAPH: Does FRP predict PM2.5?
#This is cleaner than a raw scatter since we have 170k+ points
p_h1 <- panel %>%
  filter(frp_sum_scaled > 0, frp_sum_scaled < 2) %>%
  ggplot(aes(x = frp_sum_scaled, y = pm25_scaled)) +
  geom_hex(bins = 50) +
  scale_fill_gradient(low = "#FFCCBC", high = "#BF360C",
                      name = "Count") +
  geom_smooth(method = "lm", color = "black",
              linewidth = 1, se = TRUE) +
  labs(title    = "H1: Wildfire Intensity and PM2.5",
       subtitle = "Hex bins show density of county-month observations\nBlack line is OLS fit with 95% confidence interval",
       x = "Total FRP (per 1,000 units)",
       y = "Mean PM2.5 (μg/m³)")
print(p_h1)

#H2 GRAPH: Does PM2.5 predict conflict? 
#We bin PM2.5 into deciles and show mean conflict count per bin
#This reveals whether higher pollution counties/months see more conflict
h2_plot_data <- panel %>%
  mutate(pm25_decile = ntile(pm25_scaled, 10)) %>%   #split PM2.5 into 10 groups
  group_by(pm25_decile) %>%
  summarise(
    mean_pm25     = mean(pm25_scaled,    na.rm = TRUE),
    mean_conflict = mean(conflict_count, na.rm = TRUE),
    se_conflict   = sd(conflict_count, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )
p_h2 <- ggplot(h2_plot_data, aes(x = mean_pm25, y = mean_conflict)) +
  geom_point(size = 3, color = "#9C27B0") +
  geom_errorbar(aes(ymin = mean_conflict - 1.96 * se_conflict,
                    ymax = mean_conflict + 1.96 * se_conflict),
                width = 0.3, color = "#9C27B0", alpha = 0.6) +
  geom_smooth(method = "lm", color = "#4A148C", se = TRUE, fill = "#E1BEE7") +
  labs(title    = "H2: PM2.5 and Violent Conflict",
       subtitle = "Each point = mean conflict count within a decile of PM2.5\nError bars show 95% confidence intervals",
       x = "Mean PM2.5 (μg/m³)",
       y = "Mean Conflict Count")
print(p_h2)

#H3 GRAPH: Does FRP directly predict conflict? 
#Same binning approach as H1 but now outcome is conflict count
h3_plot_data <- panel %>%
  filter(frp_sum > 0) %>%
  mutate(frp_decile = ntile(frp_sum_scaled, 10)) %>%
  group_by(frp_decile) %>%
  summarise(
    mean_frp      = mean(frp_sum_scaled, na.rm = TRUE),
    mean_conflict = mean(conflict_count, na.rm = TRUE),
    se_conflict   = sd(conflict_count, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

p_h3 <- ggplot(h3_plot_data, aes(x = mean_frp, y = mean_conflict)) +
  geom_point(size = 3, color = "#2196F3") +
  geom_errorbar(aes(ymin = mean_conflict - 1.96 * se_conflict,
                    ymax = mean_conflict + 1.96 * se_conflict),
                width = 0.5, color = "#2196F3", alpha = 0.6) +
  geom_smooth(method = "lm", color = "#0D47A1", se = TRUE, fill = "#BBDEFB") +
  labs(title    = "H3: Wildfire Activity and Violent Conflict (Direct)",
       subtitle = "Each point = mean conflict count within a decile of FRP\nError bars show 95% confidence intervals",
       x = "Mean Total FRP (per 1,000 units)",
       y = "Mean Conflict Count")

print(p_h3)

#H4 GRAPH: Coefficient plot showing mediation 
#This is the key graph for my paper because it shows how the FRP coefficient
#attenuates (shrinks) when PM2.5 is added to the model
#Attenuation = evidence of mediation through air quality

#Extract coefficients and 95% confidence intervals from H3 and H4
h4_coef_data <- bind_rows(
  #FRP coefficient from H3 (no PM2.5 in model)
  data.frame(
    model    = "H3: FRP only\n(no mediator)",
    estimate = coef(h3)["frp_sum_scaled"],
    ci_low   = confint(h3)["frp_sum_scaled", 1],
    ci_high  = confint(h3)["frp_sum_scaled", 2]
  ),
  #FRP coefficient from H4 (PM2.5 included as mediator)
  data.frame(
    model    = "H4: FRP + PM2.5\n(with mediator)",
    estimate = coef(h4)["frp_sum_scaled"],
    ci_low   = confint(h4)["frp_sum_scaled", 1],
    ci_high  = confint(h4)["frp_sum_scaled", 2]
  )
)

p_h4 <- ggplot(h4_coef_data,
               aes(x = model, y = estimate,
                   ymin = ci_low, ymax = ci_high,
                   color = model)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +  #zero line
  geom_pointrange(size = 1.2, linewidth = 1) +
  scale_color_manual(values = c("#2196F3", "#FF5722")) +
  labs(title    = "H4: Mediation — FRP Coefficient Before and After Controlling for PM2.5",
       subtitle = paste0("Attenuation of FRP coefficient suggests PM2.5 partially mediates\n",
                         "the wildfire-conflict relationship. Percent mediated: ",
                         round(pct_mediated, 1), "%"),
       x = NULL,
       y = "Coefficient on Total FRP (per 1,000 units)") +
  theme(legend.position = "none") +
  coord_flip()   #horizontal layout is easier to read for coefficient plots

print(p_h4)

#Combine all four into one figure so you can see them side by side
#install.packages("patchwork")
library(patchwork)

(p_h1 | p_h2) / (p_h3 | p_h4)  +
  plot_annotation(
    title   = "Figure 1: Visualizing the Causal Chain — Wildfire → PM2.5 → Conflict",
    subtitle = "Top row: H1 and H2 | Bottom row: H3 and H4",
    theme   = theme(plot.title = element_text(face = "bold", size = 14))
  )

