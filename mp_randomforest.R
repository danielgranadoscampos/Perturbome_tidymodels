# Multiple partition.
# Random Forest model
# Libraries ---------------------------------------------------------------

library(readr)
library(dplyr)
library(tidymodels)
library(ranger)
library(vip)
library(forcats)
library(cowplot)
library(purrr)
library(viridis)


source("classif_ind_tidy.R")


# Dataset ----------------------------------------------------------

Dataset <- read_csv("Complete_Dataset.csv")

# Remove pre-assigned column and variables not needed.
Dataset <- Dataset %>% 
  select(-Set, -Series_geo_accession, - Title,
         -Perturbation, -Sample_geo_accession,
         - Sample_title)


kreplicas = 20
ktop = 56

# Run random forest model "kreplicas" times and get results
mptable <- rerun(kreplicas, classif_ind_tidy(Dataset, ktop)) %>% 
  bind_rows()


# Look at variation in metrics from model reruns
metric_data <- mptable %>% 
  pivot_longer(cols = c("accuracy", "kappa", "roc_auc"), 
               names_to = "metric", values_to = "metric_value")

# Boxplot 
metric_boxplots <- metric_data %>%
  ggplot( aes(x=metric, y=metric_value, fill=metric)) +
  geom_boxplot() +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_bw() 

# Top 56 genes and average importance
genes <- mptable %>% 
  group_by(Variable) %>% 
  summarise(avg_imp =  mean(Importance),
            presence = n()) %>% 
  arrange(desc(presence)) %>% 
  head(56)

# Importance plot
importance_plot <- genes %>%
  mutate(Variable = fct_reorder(Variable, avg_imp)) %>%
  ggplot(aes(x = Variable, y = avg_imp)) +
  geom_segment(aes(x = Variable , xend= Variable, y=0, yend= avg_imp))+
  geom_point() +
  coord_flip() +
  theme_bw()

# Plots

mp_plots <- plot_grid(importance_plot, metric_boxplots)

ggsave("mp_rf_plot.png", mp_plots, height = 7, width = 11)

