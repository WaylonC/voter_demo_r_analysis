library(tidycensus)
library(tidyverse)
library(tigris)
library(sf)
library(tmap)
library(mapview)
library(geojsonio)
library(dplyr)
library(ggplot2)
library(ggpubr)
library(visreg)
options(tigris_use_cache = TRUE)



#------------------------------------------------------------------------
# LOAD DATA--------------------------------------------------------------
#------------------------------------------------------------------------


#Creating the demographics map for Bexar County
bexar_demographics <- get_acs(
  geography = "tract",
  variables = c(
    hisp = "B03002_012",
    income = "B19013_001",
    pop_over_25 = "DP02_0059", #population over 25. useful in determining % w college degree
    college_pop = "DP02_0068", #population of adults over 25 w a bachelors OR HIGHER
    total_population = "B01003_001"
  ),
  year = 2020,
  state = "TX",
  county = "Bexar",
  geometry = TRUE,
  output = "wide"
) %>% 
  mutate(temp_percent_hsp = 100 * ( hispE / total_populationE)) %>% #create hisp pct
  mutate(temp_college_pct = 100 * (college_popE / pop_over_25E)) %>%
  select(GEOID, # select which columns you want to retain
         hispE,
         total_populationE,
         incomeE,
         temp_college_pct,
         temp_percent_hsp) %>% 
  st_transform(3081) #transform CRS to 3081 central texas projection


#All variables have to be numeric for the interpolation. GEOID is the only character-driven one. GEOID is not necessary
#for the interpolation, and is in fact dropped later, but is useful at this point for validating that get_acs works correctly
bexar_demographics$GEOID <- as.numeric(bexar_demographics$GEOID)



#creating the BEXAR BLOCKS map from Bexar census blocks, to be used as population-weight in areal interpolations
bexar_blocks <- blocks(
  state = "TX",
  county = "Bexar",
  year = 2020
)




#Creating the 2020 precinct map with votes
target_2020 <- "bexar_precincts_2020.geojson"
precinct_map_2020 <- geojson_sf(target_2020) %>% st_transform(3081)


#Creating the 2016 precinct map with votes
target_2016 <- "bexar_precincts_2016.geojson"
precinct_map_2016 <- geojson_sf(target_2016) %>% st_transform(3081) 

#this is to project the 2016 vote numbers into the 2020 borders. Note that this loses the PREC and PCTKEY columns, though
#the 2020 PREC identifier is added back. This also makes all the columns have tons of numerals, and means that 
#the CNTY, COLOR, and CNTYKEY columns are useless now. It also messes up the order of the columns lol
precinct_map_2016 <- interpolate_pw( 
    precinct_map_2016,
    precinct_map_2020,
    to_id = "PREC",
    extensive = TRUE,
    weights = bexar_blocks,
    weight_column = "POP20",
    crs = 3081
  )




#------------------------------------------------------------------------
# COMPILING DATA---------------------------------------------------------
#------------------------------------------------------------------------



#Areally interpolate, with weighted population and assuming variables are extensive,
#the Bexar demographics map with the borders from the precinct map. The demographics map is the
#average of 2016-2020 American Community Survey, so it is relevant across both 2020 and 2016. 
#This join only uses the polygons from the precincts.
#GEOID is not retained, but it is useless.

#this will interpolate select variables seperately based on whether they are intensive or extensive


precincts_pops_extensive <- interpolate_pw(
  bexar_demographics,
  precinct_map_2020,
  to_id = "PREC",
  extensive = TRUE,
  weights = bexar_blocks,
  weight_column = "POP20",
  crs = 3081
) %>%
  select(
    PREC,
    extensive_pop_total = total_populationE
  )



#I have to get the income separately because it's intensive, not extensive. this is the diff bw weighted sums and weighted means
precincts_pops_intensive <- interpolate_pw(
  bexar_demographics,
  precinct_map_2020,
  to_id = "PREC",
  extensive = FALSE,
  weights = bexar_blocks,
  weight_column = "POP20",
  crs = 3081
) %>%
  select(
    PREC,
    intensive_pop_income = incomeE,
    intensive_pop_college = temp_college_pct,
    intensive_pop_hisp = temp_percent_hsp
    )


#Now I have two maps that have estimated demographic data inside precincts. Let's merge them.
#Before we can merge them, we have to drop the geographic data
precincts_pops_intensive <- precincts_pops_intensive %>% st_drop_geometry()
precincts_pops_extensive <- precincts_pops_extensive %>% st_drop_geometry()

precincts_pops <- inner_join(
  precincts_pops_intensive,
  precincts_pops_extensive,
  by="PREC"
  )




#now we have this great map of precincts with demo data. and it even has the precinct ID.
#Now to start merging this dataframe w the precinct dataframe that has the voting numbers. 


precinct_map_2020 <- precinct_map_2020 %>% st_drop_geometry() %>% 
  mutate(votes_total_2020 = rowSums(.[8:12])) #adding up all the columns for presidential candidates, including the third parties

precinct_map_2016 <- precinct_map_2016 %>% st_drop_geometry() %>%
  mutate(votes_total_2016 = rowSums(.[7:11])) #the columns are different because the earlier projection into 2020 boundaries deleted the CNTYKEY column

precinct_map <- inner_join(
  precinct_map_2016,
  precinct_map_2020,
  by="PREC"
  )


#now to add the demo data (under precinct polygon) to the precinct data (under precinct polygon)
precincts_pops_votes <- inner_join(
  precincts_pops,
  precinct_map,
  by="PREC"
  ) %>%
  mutate(VR_turnout_2020 = 100 * (votes_total_2020 / G20VR)) %>% #new to harvard...
  mutate(VR_turnout_2016 = 100 * (votes_total_2016 / G16VR)) %>%
  mutate(votes_trump_pct_2020 = 100 * (G20PRERTRU / votes_total_2020)) %>%
  mutate(votes_biden_pct_2020 = 100 * (G20PREDBID / votes_total_2020)) %>%
  mutate(votes_trump_pct_2016 = 100 * (G16PRERTRU / votes_total_2016)) %>%
  mutate(votes_clinton_pct_2016 = 100 * (G16PREDCLI / votes_total_2016)) %>%
  select(
    PREC,
    pop_total = extensive_pop_total,
    pop_hisp_pct = intensive_pop_hisp,
    pop_income = intensive_pop_income,
    pop_college_pct = intensive_pop_college,
    VR_total_2020 = G20VR,
    VR_hisp_pct_2020 = G20SSVR, #remember, this is the PCT of hispanic surnames in the Voter registration roles
    VR_turnout_2020,
    votes_trump_2020 = G20PRERTRU, 
    votes_biden_2020 = G20PREDBID, 
    votes_trump_pct_2020, 
    votes_biden_pct_2020, 
    votes_total_2020,
    VR_total_2016 = G16VR,
    VR_hisp_pct_2016 = G16SSVR, #remember, this is the PCT of hispanic surnames in the Voter registration roles
    VR_turnout_2016,
    votes_trump_2016 = G16PRERTRU,
    votes_clinton_2016 = G16PREDCLI,
    votes_trump_pct_2016,
    votes_total_2016,
    votes_clinton_pct_2016
  ) %>%
  mutate(votes_trump_difference = votes_trump_pct_2020 - votes_trump_pct_2016)


#filter out any precincts with less than 200 voters registering in either 2020 or 2016. This cuts it from 703 to 567 precincts
precincts_pops_votes <- precincts_pops_votes %>% filter(VR_total_2020 > 200 & VR_total_2016 > 200) 



#OPTIONAL BERNIE ANALYSIS!!!
#Though it doesn't exactly show anything too significant
bernie_2020_target <- "C:/Users/waylo/Documents/San Antonio Report/2022/7 july/voting and census info/dem_primary_precincts_2020_refined.csv" 
bernie_2020 <- read.csv(file = bernie_2020_target) %>% filter(total>50) %>% select(PREC,votes_bernie_pct_2020 = bernie__pct)
bernie_2020$PREC <- as.character(bernie_2020$PREC)

precincts_pops_votes <- inner_join(
  precincts_pops_votes,
  bernie_2020,
  by="PREC"
)




#export to csv
write.csv(precincts_pops_votes,"precincts_pops_votes.csv", row.names = FALSE)


#------------------------------------------------------------------------
#PLOT DATA---------------------------------------------------------------
#------------------------------------------------------------------------



#looking at the DIFFERENCE between 2016 and 2020......

#precincts with higher hisp percentage more likely to see INCREASED support for trump b/w 2016-2020
ggplot(data = precincts_pops_votes, aes(x = pop_hisp_pct, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')


#precincts with lower income more likely to see INCREASED support for trump b/w 2016-2020
ggplot(data = precincts_pops_votes, aes(x = pop_income, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')


#precincts with lower educational attainment more like to see INCREASED support for trump b/w 2016-2020
ggplot(data = precincts_pops_votes, aes(x = pop_college_pct, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')


#-----------------

#looking at the TOTAL for 2020 alone...


#predominantly hisp precincts still slated against trump in 2020
ggplot(data = precincts_pops_votes, aes(x = pop_hisp_pct, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')


# higher income = more support for trump in 2020
ggplot(data = precincts_pops_votes, aes(x = pop_income, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')


#higher educational attainment associated with support of trump in 2020
ggplot(data = precincts_pops_votes, aes(x = pop_college_pct, y = votes_trump_difference)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')

ggplot(data = precincts_pops_votes, aes(x = pop_college_pct, y = votes_trump_pct)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')




#--------------

#looking at bernie....
#ok.... i dont see anything statistically significant :/

ggplot(data = precincts_pops_votes, aes(x = votes_trump_pct_2016, y = votes_bernie_pct_2020)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')

ggplot(data = precincts_pops_votes, aes(x = pop_income, y = votes_bernie_pct_2020)) +
  geom_point() +
  geom_smooth(method=lm,col='blue')







