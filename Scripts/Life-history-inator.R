#Life-history-inator.R
#This script uses FishBase to scrape data to make life history calculations
#Froese, R. and Binohlan, C. (2000). Empirical relationships to estimate asymptotic length, length at first maturity and length at maximum yield per recruit in fishes. Journal of Fish Biology, 56(4), pp. 758–773.
#Jensen, A. L. (1996). Beverton and Holt life history invariants result from optimal trade-off between survival and reproduction. Canadian Journal of Fisheries and Aquatic Sciences, 53(4), pp. 820–822.
#Pauly, D. (1980). On the interrelationships between natural mortality, growth parameters, and mean environmental temperature in 175 fish stocks. Journal du Conseil, 39(2), pp. 175–192.
#Then, A. Y., Hoenig, J. M., Hall, N. G., & Hewitt, D. A. (2015). Evaluating the predictive performance of empirical estimators for natural mortality rate using information on 201 fish species. ICES Journal of Marine Science, 72(1), pp. 82–92.

#THIS IS IN PROGRESS

library(rfishbase)
life_history <- df(genus = NA,
                   species = NA,
                   common_name = NA)