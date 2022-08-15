# This function executes the multiple partitions


classif_ind_tidy <- function(fdata, fktop){
  
  #splitting
  data_split <- initial_split(fdata, prop = .80, strata = Class)
  dtraining <- training(data_split)
  dtesting <- testing(data_split)
  
  # cv folds
  
  training_folds <- vfold_cv(dtraining, strata = Class)
  
  # Training
  
  recipe <- 
    recipe(formula = Class ~ ., data = dtraining) %>% 
    step_string2factor(one_of("Class")) 
  
  spec <- 
    rand_forest(mtry = tune(), min_n = tune(),trees = 1000) %>% 
    set_mode("classification") %>% 
    set_engine("ranger") 
  
  model_workflow <- 
    workflow() %>% 
    add_recipe(rf_recipe) %>% 
    add_model(rf_spec)
  
  doParallel::registerDoParallel()
  
  # Tuning
  model_tune <-
    tune_grid(rf_workflow, 
              resamples = training_folds, 
              grid = 25,
              metrics = metric_set(accuracy, kap, roc_auc))
  
  
  # Importance
  
  imp_spec <- spec %>%
    finalize_model(select_best(model_tune, metric = "accuracy")) %>%
    set_engine("ranger", importance = "permutation")
  
  
  imp_scores <- workflow() %>%
    add_recipe(recipe) %>%
    add_model(imp_spec) %>%
    fit(dtraining) %>%
    extract_fit_parsnip() %>%
    vi(rank = TRUE) %>% 
    head(n = fktop)
  
  # Rebuild dataset
  
  dataset_ranked <- fdata %>% 
    select(all_of(imp_scores$variable))
  
  ranked_split <- initial_split(dataset_ranked, strata = Class)
  
  dtraining_ranked <- training(ranked_split)
  
  dtesting_ranked <- testing(ranked_split)
  
  ranked_folds <- vfold_cv(dtraining_ranked, strata = Class)
  
  # Model with new dataset
  
  ranked_recipe <-
    recipe(formula = Class ~ ., data = dtraining_ranked) %>%
    step_string2factor(one_of("Class"))

  ranked_workflow <-
    workflow() %>%
    add_recipe(ranked_recipe) %>%
    add_model(spec)

  # Tuning
  ranked_tune <-
    tune_grid(ranked_workflow,
              resamples = ranked_folds,
              grid = 25,
              metrics = metric_set(accuracy, kap, roc_auc))
  
  

# Importance of the ranked genes
  
  ranked_imp_spec <- spec %>%
    finalize_model(select_best(ranked_tune, metric = "accuracy")) %>%
    set_engine("ranger", importance = "permutation")
  
  final_rf_fit <- last_fit(final_rf, Dataset_split,
                           metrics = metric_set(accuracy, kap, roc_auc))
  
  ranked_imp_scores <- workflow() %>%
    add_recipe(ranked_recipe) %>%
    add_model(ranked_imp_spec) %>%
    fit(dtraining_ranked) %>%
    extract_fit_parsnip() %>%
    vi(rank = TRUE) %>% 
    head(n = fktop)
  
  
  # Genes and metrics
  
  output <- ranked_imp_scores %>% 
    select(Variable) %>% 
    mutate()

  
  
}