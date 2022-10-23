The spreadsheet "precincts_pops_votes" shows estimates of the demographics of election precincts, along
with how those precincts voted in 2016 and in 2020.

My own analysis of it shows that in both 2016 and 2020, lower incomes, lower
educational attainment and a higher percentage of Hispanic-identifying residents were
all correlated with LOW support of Trump/Republicans.

However, between 2016 and 2020, there were changes. Lower incomes, lower
educational attainment, and higher percentages of Hispanic-identifying residents were 
all correlated with INCREASING support for Trump/Republicans. Conversely, higher income,
higher educational attainment, and a lower percentage of Hispanic-identifying residents 
were correlated with LOWERED support for Trump. 

This shift between 2016 and 2020 does not appear to be showing polarization. Instead,
it appears to show a growing political realignment.

My question is, which is the most important variable? Class? Ethnicity? Education?

The columns are as follows:

*PREC = Precinct number
*pop_total = Estimated population total in the precinct
*pop_hisp_pct = Estimated percentage of population identifying as Hispanic in the precinct
*pop_income = Estimated median household income in the precinct
*pop_college_pct = Estimated percentage of residents over 25 with a bachelor's degree in the precinct
*VR_total_2020 = Total voter registrations in the precinct in 2020
*VR_hisp_pct_2020 = Percent of voter registrations with Spanish surname in the precinct (matches
	closely with pop_hisp_pct) in 2020
*VR_turnout_2020 = Voter turnout as a percentage in the precinct in 2020
*votes_trump_2020 = Total votes for Trump in the precinct in 2020
*votes_biden_2020 = Total votes for Biden in the precinct in 2020
*votes_trump_pct_2020 = Percentage of votes for Trump in the precinct in 2020
*votes_biden_pct_2020 = Percentage of votes for Biden in the precinct in 2020
*votes_total_2020 = Total votes cast in the precinct in 2020
*VR_total_2016 = Estimated total voter registration in the precinct in 2016
*VR_hisp_pct_2020 = Estimated percent of voter registrations with Spanish surname in 
	the precinct (matches closely with pop_hisp_pct) in 2016
*VR_turnout_2020 = Estimated voter turnout as a percentage in the precinct in 2016
*votes_trump_2016 = Estimated votes for Trump in precinct in 2016
*votes_clinton_2016 = Estimated votes for Clinton in precinct in 2016
*votes_total_2016 = Estimated total votes in the precinct in 2016
*votes_trump_pct_2016 = Estimated percentage of votes for Trump in the precinct in 2016
*votes_clinton_pct_2016 = Estimated percentage of votes for Clinton in the precinct in 2016
*votes_total_2016 = Estimated total votes cast in precinct in 2016
*votes_trump_difference = Difference between Trump's percentage in 2016 and in 2020 for the precinct



-----------------------------

METHODOLOGY:

This spreadsheet was compiled in R with demographic data from the 2016-2020 ACS Census information,
and with precinct voting records and shapefiles as recorded by Harvard's election research team.

Precinct data from 2016 was loaded into 2020 precinct boundaries using
population-weighted, extensive areal interpolation. 

Using the same method, demographic data from the census was also loaded into 2020 precinct boundaries.

A spreadsheet was created to combine all three datasets (2016 votes, 2020 votes, 2016-2020 demographics)
into the boundaries of 2020 precincts.

Precincts with less than 200 total voter registrations in 2020 or 2016 were filtered out. 

If you want to recreate this methodology, you can do so.

All the necessary files are included in the "How the Sausage is made" folder. Download all of them,
and then run the R file in whatever R software you have. The only edit that will need to be made
is to lines 68 and 73. These are what indicate the file path to the 2016 and 2020 .geojson files
respectively. Right now they are set to these files' location on my computer, but they will of course
differ depending on where you download these files to. 

