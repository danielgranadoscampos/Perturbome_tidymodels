#Single partition.
# K-nearest neighbor model
# Libraries ---------------------------------------------------------------

library(readr)
library(dplyr)
library(tidymodels)
library(kknn)
library(vip)
library(forcats)
library(cowplot)
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


# K-nearest neighbor model with tidymodels --------------------------------

kknn_recipe <- 
  recipe(formula = Class ~ ., data = Dtraining) %>% 
  step_string2factor(one_of("Class"), skip = TRUE) #%>% 
  #step_zv(all_predictors()) %>% 
  #step_normalize(all_numeric_predictors()) This should be standard steps
  # for a kknn model if the data had no been normalized at this point (not like in
  # the paper's case)

kknn_spec <- 
  nearest_neighbor(neighbors = tune(), weight_func = tune()) %>% 
  set_mode("classification") %>% 
  set_engine("kknn") 

kknn_workflow <- 
  workflow() %>% 
  add_recipe(kknn_recipe) %>% 
  add_model(kknn_spec) 

kknn_params <- extract_parameter_set_dials(kknn_spec)
kknn_grid <- grid_regular(kknn_params)

set.seed(20298)
kknn_tune <-
  tune_grid(kknn_workflow, 
            resamples = training_folds, 
            grid = kknn_grid,
            control = keep_pred) #this may take over an hour

# Selecting the best model
# Accuracy is chosen as in the paper, but roc_auc may yiedl better results
final_kknn <- kknn_workflow %>%
  finalize_workflow(select_best(kknn_tune, metric = "accuracy"))

final_kknn_fit <- last_fit(final_kknn, Dataset_split)


# Model effectiveness -----------------------------------------------------


metrics <- collect_metrics(final_kknn_fit)


## Confusion matrix ----
conf_mat_plot <- final_kknn_fit %>% 
  collect_predictions() %>% 
  conf_mat(truth = Class, estimate =.pred_class) %>% 
  autoplot(type = "heatmap")


## ROC curve ----
roc_plot <- final_kknn_fit %>% 
  collect_predictions() %>% 
  roc_curve(truth = Class, .pred_Control) %>% 
  autoplot()
roc_plot


## Saving plots
plot_row <- plot_grid(roc_plot, conf_mat_plot)
ggsave("kknn_model_plots.png", plot_row, height = 3)

## Importance score (in development) ----

# kknn_imp_spec <- kknn_spec %>%
#   finalize_model(select_best(kknn_tune, metric = "accuracy")) %>%
#   set_engine("kknn")
# 
# 
# kknn_feature_names <- Dtraining %>% 
#   select(-Class) %>% 
#   names()
# 
# kknn_imp_scores <- workflow() %>%
#   add_recipe(kknn_recipe) %>%
#   add_model(kknn_imp_spec) %>%
#   fit(Dtraining) %>%
#   extract_fit_parsnip() %>%
#   vi(method = "firm", kknn_feature_names, 
#     train = Dtraining)
# 
# 
# importance_plot <- svm_imp %>%
#   mutate(Variable = fct_reorder(Variable, Importance)) %>%
#   slice_head(n=20) %>%
#   ggplot(aes(x = Variable, y = Importance)) +
#   geom_segment(aes(x = Variable , xend= Variable, y=0, yend= Importance))+
#   geom_point() +
#   coord_flip() +
#   theme_bw()