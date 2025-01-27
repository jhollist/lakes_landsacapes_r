library(fulltext)
library(rcrossref)
library(dplyr)
library(purrr)
library(stringr)
library(lubridate)
library(readr)

if(!file.exists("le_works.rda")){
  le_works <- cr_works(filter = c(issn = "1572-9761", 
                                  from_pub_date = "1993-08-01",
                                  until_pub_date = "2011-10-01"), limit = 1000)
  le_works2 <- cr_works(filter = c(issn = "1572-9761", 
                                   from_pub_date = "2011-10-02",
                                   until_pub_date = "2018-04-02"), limit = 1000)
  le_works_all <- bind_rows(le_works$data, le_works2$data)
  save(le_works_all, file = "le_works.rda")
}

load("le_works.rda")

le_works_small <- le_works_all %>%
  mutate(year = str_sub(issued,1, 4)) %>%
  select(doi = DOI, year)

if(!file.exists("le_fulltext.rda")){
  ft_get_collect <- function(x){
    suppressMessages({
      ft_get(x) %>% 
        ft_collect()
    })
  }
  possible_ft<- possibly(ft_get_collect,otherwise = "ERROR")
  
  pb <- progress_estimated(length(le_works_small$doi))
  le_works_small$doi %>%
    map(~{
      # update the progress bar (tick()) and print progress (print())
      pb$tick()$print()
      Sys.sleep(0.001)
      possible_ft(.)
    })
  
  files <- list.files("c:/Users/JHollist/AppData/Local/Cache/R/fulltext/", 
                      "*.pdf", full.names = TRUE)
  pb<- progress_estimated(length(files))
  poss_readtext <- possibly(readtext::readtext, 
                            otherwise = "error", quiet = TRUE)
  le_table<-files %>%
    map(~ {
      # update the progress bar (tick()) and print progress (print())
      pb$tick()$print()
      Sys.sleep(0.000001)
      poss_readtext(.)
    })

  le_table_df <- do.call(rbind.data.frame, le_table)

  le_table_df <- le_table_df %>%
    mutate(doi = str_remove(doc_id,".pdf")) %>%
    mutate(doi = str_replace(doi,"10_1007_","10.1007/")) %>%
    mutate(doi = str_replace_all(doi,"_", "-")) %>%
    full_join(le_works_small) %>%
    filter(doc_id != "error") %>%
    unique()
  
  save(le_table_df, file = "le_fulltext.rda")
}

load("le_fulltext.rda")

le_table_r <- le_table_df %>%
  mutate(low_text = str_to_lower(text)) %>%
  mutate(cites_r = grepl(" cran ", .$low_text) |
           grepl(" r package ", .$low_text) |
           grepl(" r version ", .$low_text),
         cites_sas = grepl(" sas ", .$low_text) |
           grepl(" sas institute", .$low_text),
         cites_python = grepl(" python ", .$low_text),
         cites_splus = grepl(" splus", .$low_text) |
           grepl(" s\\+ ", .$low_text) |
           grepl(" s-plus ", .$low_text) |
           grepl(" s plus ", .$low_text),
         cites_excel = grepl(" excel ", .$low_text)) %>%
  select(doi, cites_r, cites_sas, cites_python, cites_splus, cites_excel, year)

le_r_yearly <- le_table_r %>%
  filter(doi != "error") %>%
  group_by(year) %>%
  summarize(num_articles = n(),
            r = sum(cites_r),
            sas = sum(cites_sas),
            python = sum(cites_python),
            splus = sum(cites_splus),
            excel = sum(cites_excel)) %>%
  write_csv("le_lang_year.csv")




