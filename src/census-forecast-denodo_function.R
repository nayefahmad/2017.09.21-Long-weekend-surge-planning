

#*****************************************************
# Function to produce census forecast for given date range 
#*****************************************************

# import df with holidays specified: 
options(readr.default_locale=readr::locale(tz="America/Los_Angeles"))

holidays <- read_csv(here::here("data", 
                                "2019-05-13_holidays-data-frame.csv"))



# function definition: 
census_forecast <- function(startdate_id, 
                            enddate_id, 
                            past_years = 3,  # todo: change to 5?  
                            site = "Lions Gate Hospital", 
                            n_unit, 
                            holidays_df = NULL, 
                            fcast_only = TRUE, 
                            changepoints_vec = NULL, 
                            trend_flexibility = 0.05,  # default set by prophet
                            save_plots = FALSE, 
                            denodo_vw = vw_census){
      
      # inputs: 
      # > start and end date_id: the date range for which to return forecast
      # > past_years: how many years historical data to pull for fitting the trend 
      # > n_unit: the nursing unit to forecast census for 
      # > fcast_only: if TRUE, return only the fcast, not the historical data pulled as well
      
      # outputs: 
      # > dataframe with columns: date_id, nursing_unit_cd, metric, value
      # > levels of "metric" field: predicted, prediction_lower, prediction_upper
      
      library(lubridate)
      library(stringr)

      # check wheter holidays dataframe has been specified: 
      # stopifnot(exists(holidays_df))
      
      
      # historical data range: --------
      historical_start <- lubridate::ymd(startdate_id) -1 - years(past_years)
      historical_end <- lubridate::ymd(startdate_id) -1 
      
      # start and end as date_ids: 
      historical_start_id <- 
            historical_start %>% 
            as.character( ) %>% 
            str_replace_all("-", "")
      
      historical_end_id <- 
            historical_end %>% 
            as.character( ) %>% 
            str_replace_all("-", "")
      
      
      # full date list to join on, in case dates missing in census: 
      full_date_list <- 
            data.frame(date = seq(historical_start, 
                                  historical_end, 
                                  by = "1 day")) %>% 
            mutate(date_id = map_int(date, 
                                     function(x){
                                           x %>% as.character() %>% 
                                                 str_replace_all("-", "") %>% 
                                                 as.integer()
                                    }
                              ))
      
      
      # horizon to forecast: ------------
      horizon_param <- difftime(ymd(enddate_id),
                                ymd(startdate_id)) %>% 
            as.integer() + 1
      
      # print(list(historical_start, 
      #            historical_end, 
      #            horizon_param))
      
      
      # pull historical data from denodo, using extract_census( ) function: 
      census <- extract_census(historical_start_id, 
                               historical_end_id, 
                               n_units = n_unit) %>% 
            ungroup() %>%  # convert from grouped_df to df
            right_join(full_date_list)
      
      
      
      # set up data for prophet:  
      census <- census %>% 
            select(date, 
                   value) %>% 
            rename(ds = date, 
                   y = value)
      
      
      # fit prophet model: ------------------------------
      library(prophet)
      
      m <- prophet(census, 
                   holidays = holidays_df, 
                   changepoints = changepoints_vec, 
                   changepoint.prior.scale = trend_flexibility)
      
      future <- make_future_dataframe(m, 
                                      periods = horizon_param,
                                      freq = "day")  
      
      fcast <- predict(m, future)  # to be used for plotting below
            
      fcast_modified <- fcast %>%  # to be returned by the function
            select(ds, 
                   yhat_lower, 
                   yhat, 
                   yhat_upper) %>% 
            
            rename(census_lower_ci = yhat_lower, 
                   census_fcast = yhat, 
                   census_upper_ci = yhat_upper) %>% 
            
            # reformat result: 
            mutate(date_id = map_int(ds, 
                                     function(x){
                                           x %>% as.character() %>% 
                                                 str_replace_all("-", "") %>% 
                                                 as.integer()
                                     })) %>% 
            select(date_id, ds, everything()) %>% 
            
            # return historical pull as well as fcast? 
            {if (fcast_only) {filter(., date_id >= startdate_id)
                  } else {.}}
            
      # save forecast and plot components
      plot_fitted <- plot(m, fcast)
      plot_components <- prophet_plot_components(m, fcast)
      
      # print forecast and plot components: 
      print(plot(m, fcast))
      print(prophet_plot_components(m, fcast))
      
      if (save_plots) {
            return(list(fcast_modified, 
                        plot_fitted, 
                        plot_components))
      } else {
            return(fcast_modified)
      }
      
      
}




# test the function: ------
# startdate_id <- "20190401"
# enddate_id <- "20190512"
# 
# census_actual <- extract_census(startdate_id,
#                                 enddate_id,
#                                 n_units = "LGH 2E")
# 
# 
# census_fcast <- census_forecast(startdate_id,  
#                                 enddate_id, 
#                                 n_unit = "LGH 2E", 
#                                 changepoints_vec = c("2018-04-01", 
#                                                      "2019-02-01", 
#                                                      "2019-02-02"), 
#                                 trend_flexibility = 0.05, 
#                                 save_plots = FALSE, 
#                                 holidays_df = holidays)

# str(census_fcast)

# census_fcast_tail <- 
#       census_fcast %>% 
#       filter(date_id >= startdate_id) #  %>% write.table(file = "clipboard", sep = "\t", row.names = FALSE)


# plot comparing actual with forecast: 
# census_fcast %>% 
#       ggplot(aes(x = ds, 
#                  y = yhat)) + 
#       geom_ribbon(aes(x = ds, 
#                       ymin = yhat_lower, 
#                       ymax = yhat_upper), 
#                   fill = "grey80", 
#                   alpha = 0.5) +
#       geom_line(col = "skyblue") + 
#       geom_point(col = "skyblue") + 
#       
#       geom_line(data = census_actual %>% 
#                       bind_cols(census_fcast %>% select(ds)), 
#                 aes(x = ds, 
#                     y = value), 
#                 col = "blue") + 
#       
#       theme_light() +
#       theme(panel.grid.minor = element_line(colour = "grey95"), 
#               panel.grid.major = element_line(colour = "grey95"))
              
      
