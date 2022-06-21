#Single partition.
# Random Forest model
# Libraries ---------------------------------------------------------------

library(readr)
library(dplyr)
library(tidymodels)
library(ranger)
library(vip)
library(forcats)
library(cowplot)


# Dataset ----------------------------------------------------------

Dataset <- read_csv("Complete_Dataset.csv")

# Remove pre-assigned column and variables not needed.
Dataset <- Dataset %>% 
  select(-Set, -Series_geo_accession, - Title,
         -Perturbation, -Sample_geo_accession,
         - Sample_title)


# Data partitioning -------------------------------------------------------
# Rather than using the pre-asigned value that is used in the original
# single partiion method code, a split will be used to follow a typical 
# tidymodels wotkflow.
set.seed(123)
Dataset_split <- initial_split(Dataset, prop = .70, strata = Class)
Dtraining  <- training(Dataset_split)
Dtesting <- testing(Dataset_split)



# Resamples preparation ---------------------------------------------------

set.seed(345)
training_folds <- vfold_cv(Dtraining, strata = Class)

# Random Forest model with Tidymodels -------------------------------------

rf_recipe <- 
  recipe(formula = Class ~ ., data = Dtraining) %>% 
  step_string2factor(one_of("Class")) 

rf_spec <- 
  rand_forest(mtry = tune(), min_n = tune(),trees = 1000) %>% 
  set_mode("classification") %>% 
  set_engine("ranger") 

rf_workflow <- 
  workflow() %>% 
  add_recipe(rf_recipe) %>% 
  add_model(rf_spec)

# Tuning
set.seed(14426)
ranger_tune <-
  tune_grid(rf_workflow, 
            resamples = training_folds, 
            grid = 20)

# Selecting best model

final_rf <- rf_workflow %>%
  finalize_workflow(select_best(ranger_tune, metric = "accuracy"))

final_rf_fit <- last_fit(final_rf, Dataset_split)

# Model effectiveness
collect_metrics(final_rf_fit)

predictions <- collect_predictions(final_rf_fit)

conf_mat(predictions, truth = Class, estimate = .pred_class)

roc_plot <- roc_curve(predictions, truth = Class, .pred_Control) %>% 
  autoplot()


#  Genes ranking by "importance" ------------------------------------------
# Here permutation feature importance is used , this is
# a different method to the one used in caret::varImp()

imp_spec <- rf_spec %>%
  finalize_model(select_best(ranger_tune, metric = "accuracy")) %>%
  set_engine("ranger", importance = "permutation")

imp_scores <- workflow() %>%
  add_recipe(rf_recipe) %>%
  add_model(imp_spec) %>%
  fit(Dtraining) %>%
  extract_fit_parsnip() %>%
  vi()

importance_plot <- imp_scores %>%
  mutate(Variable = fct_reorder(Variable, Importance)) %>%
  slice_head(n=20) %>% 
  ggplot(aes(x = Variable, y = Importance)) +
  geom_segment(aes(x = Variable , xend= Variable, y=0, yend= Importance))+
  geom_point() +
  coord_flip() +
  theme_bw()

## Saving plots
plot_row <- plot_grid(importance_plot, roc_plot)
ggsave("model_plots.png", plot_row, height = 3)
