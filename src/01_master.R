
#***********************************************************
# LGH SURGE PLANNING: EXTRACT PAST YEAR ADTC data, ed visits
# 2019-05-03
# Nayef 


#***********************************************************

library(odbc)
library(dbplyr)
library(magrittr)  
library(tidyverse)
library(here)

# rm(list = ls())

# 1) parameters: --------------
startdate_id <- "20180803"
enddate_id <- "20180807"

startdate_id_for_fcast <- "20190802"
enddate_id_for_fcast <- "20190806"


n_units_param <- c("LGH 2E",
                   "LGH 3E", 
                   "LGH 3W", 
                   "LGH 4E",
                   "LGH 4W",
                   "LGH 5E",
                   "LGH 6E",
                   "LGH 6W",
                   "LGH 7E",
                   "LGH 7W", 
                   "LGH 7W", 
                   "LGH EIP", 
                   "LGH ICU",
                   "LGH MIU"
                   )


# 2) set up database connections: -----------
source(here::here("src", 
                  "setup-denodo_function.R"))

setup_denodo()


# 3) Import functions for pulling data: ---------
source(here::here("src", 
            "census-denodo_function.R"))
source(here::here("src", 
            "ed-visits-denodo_function.R"))
source(here::here("src", 
            "admits-denodo_function.R"))


# 4) Run functions: ----------

# LGH data: 
census <- extract_census(startdate_id, 
                         enddate_id, 
                         n_units = n_units_param)

ed_visits <- extract_ed_visits(startdate_id, 
                               enddate_id)

admits <- extract_admits(startdate_id, 
                         enddate_id)


# LGH HOpe Centre data: 
census_hope_centre <- extract_census(startdate_id, 
                                     enddate_id, 
                                     site = "LGH HOpe Centre", 
                                     n_units = "LGH MIU")

admits_hope_centre <- extract_admits(startdate_id, 
                                     enddate_id, 
                                     site = "LGH HOpe Centre", 
                                     n_units = "LGH MIU")






# 5) Import and run function for ED visits forcast: --------------
source(here::here("src", 
                  "ed-visits-forecast-denodo_function.R"))

# Import holidays dataframe: 
options(readr.default_locale=readr::locale(tz="America/Los_Angeles"))
holidays <- read_csv(here::here("data", 
                                "2019-05-13_holidays-data-frame.csv")) %>% 
      mutate(ds = mdy(ds))

# run forecast: 
edvisits_fcast <- edvisits_forecast(startdate_id_for_fcast, 
                                    enddate_id_for_fcast ,
                                    holidays_df = holidays) 

edvisits_fcast <- edvisits_fcast[[1]] %>% 
      as.data.frame() %>% 
      
      # reformat to match other results: 
      gather(key = "metric", 
             value = "value", 
             -c(date_id, 
                ds)) %>% 
      
      mutate(nursing_unit_cd = NA) %>% 
      select(date_id, 
             nursing_unit_cd, 
             metric, 
             value)
      


# 6) join all together in one df: -------------
df1.surge_planning_data <- 
      census %>% 
      bind_rows(census_hope_centre, 
                admits, 
                admits_hope_centre, 
                ed_visits)  





# 7) write output: -----------
write_csv(df1.surge_planning_data,
          here::here("results",
                     "output from src",
                     "2019-07-16_lgh_surge-planning-data.csv"))
                         
write_csv(edvisits_fcast,
          here::here("results",
                     "output from src",
                     "2019-07-16_lgh_ed-visits-fcast.csv"))
                         
