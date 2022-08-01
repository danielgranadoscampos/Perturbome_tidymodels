# Single Partition
# SVM model

#Libraries ---------------------------------------------------------------
  
library(readr)
library(dplyr)
library(tidymodels)
library(kernlab)
library(vip)
library(forcats)
library(cowplot)
library(foreach)
library(pdp)


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
keep_pred <- control_resamples(save_pred = TRUE)


# Support Vector Machine with tidymodels ----------------------------------

svm_recipe <- 
  recipe(formula = Class ~ ., data = Dtraining) 

svm_spec <- 
  svm_rbf(cost = tune(), rbf_sigma = tune()) %>% 
  set_mode("classification") %>% 
  set_engine("kernlab")

svm_params <- extract_parameter_set_dials(svm_spec)
svm_grid <- grid_regular(svm_params)

svm_workflow <- 
  workflow() %>% 
  add_recipe(svm_recipe) %>% 
  add_model(svm_spec) 

set.seed(20298)
svm_tune <-
  tune_grid(svm_workflow, 
            resamples = training_folds, 
            grid = svm_grid,
            control = keep_pred)

## Selecting the best model ---- 
# Accuracy is chosen as in the paper, but roc_auc may yiedl better results
final_svm <- svm_workflow %>%
  finalize_workflow(select_best(svm_tune, metric = "accuracy"))

final_svm_fit <- last_fit(final_svm, Dataset_split)



# Checking effectiveness --------------------------------------------------

## Metrics ----
accuracy <- final_svm_fit %>% 
  collect_metrics() %>% 
  filter(.metric == "accuracy")



## Confusion matrix ----
conf_mat_plot <- final_svm_fit %>% 
  collect_predictions() %>% 
  conf_mat(truth = Class, estimate =.pred_class) %>% 
  autoplot(type = "heatmap")


## ROC curve ----
roc_plot <- final_svm_fit %>% 
  collect_predictions() %>% 
  roc_curve(truth = Class, .pred_Control) %>% 
  autoplot()
roc_plot


## Saving plots
plot_row <- plot_grid(roc_plot, conf_mat_plot)
ggsave("svm_model_plots.png", plot_row, height = 3)


## Importance score (in development) ----
# FIRM approach is used

#Finalize model with best tune
svm_imp_spec <- svm_spec %>%
  finalize_model(select_best(svm_tune, metric = "accuracy")) %>%
  set_engine("kernlab", importance = "permutation")

#Get feature names
svm_feature_names <- Dtraining %>% 
  select(-Class) %>% 
  names()
# FIRM based importance
svm_imp_scores <- workflow() %>%
  add_recipe(svm_recipe) %>%
  add_model(svm_imp_spec) %>%
  fit(Dtraining) %>%
  extract_fit_parsnip() %>%
  vi(method = "firm", svm_feature_names, 
     train = Dtraining) #this takes a long time

# Importance plot
importance_plot <- svm_imp_scores %>%
  mutate(Variable = fct_reorder(Variable, Importance)) %>%
  slice_head(n=20) %>%
  ggplot(aes(x = Variable, y = Importance)) +
  geom_segment(aes(x = Variable , xend= Variable, y=0, yend= Importance))+
  geom_point() +
  coord_flip() +
  theme_bw()

## Saving plots
plot_top_row <- plot_grid(roc_plot, conf_mat_plot)

full_plot <- plot_grid(plot_top_row, importance_plot, ncol = 1)

ggsave("svm_model_plots.png", full_plot, height = 6)
