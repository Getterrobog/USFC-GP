library(dplyr)

Fish_Family_Freq <- Fish %>% 
  count(Order, Family, sort = FALSE) %>% 
  group_by(Order) %>% 
  mutate(max_n = max(n)) %>% 
  ungroup() %>% 
  arrange(desc(max_n), Order, desc(n), Family) %>% 
  select(-max_n)

write.csv(Fish_Family_Freq, "./Output/Files/Fish_Family_Freq.csv", row.names = FALSE)