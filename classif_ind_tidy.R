# This function executes the multiple partitions


classif_ind_tidy <- function(fdata, fktop){
  
  #splitting
  data_split <- initial_split(fdata, prop = .80, strata = Class)
  dtraining <- training(data_split)
  dtesting <- testing(data_split)
  
  # cv folds
  
  training_folds <- vfold_cv(Dtraining, strata = Class)
  
  # Training
  
  recipe <- 
    recipe(formula = Class ~ ., data = Dtraining) %>% 
    step_string2factor(one_of("Class")) 
  
  spec <- 
    rand_forest(mtry = tune(), min_n = tune(),trees = 1000) %>% 
    set_mode("classification") %>% 
    set_engine("ranger") 
  
  params <- extract_parameter_set_dials(spec)
  regular_grid <- grid_regular(params)
  
  model_workflow <- 
    workflow() %>% 
    add_recipe(recipe) %>% 
    add_model(spec)
  
  # Tuning
  set.seed(14426)
  model_tune <-
    tune_grid(model_workflow, 
              resamples = training_folds, 
              grid = regular_grid)
  
  class_metrics <- metric_set(accuracy, kap)
  
  
  # model_metrics <- model_tune %>% 
  #   class_metrics()
  
  # Importance
  
  imp_spec <- spec %>%
    finalize_model(select_best(model_tune, metric = "accuracy")) %>%
    set_engine("ranger", importance = "permutation")
  
  preds <- augment
  
  imp_scores <- workflow() %>%
    add_recipe(recipe) %>%
    add_model(imp_spec) %>%
    fit(Dtraining) %>%
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
  
  # 
  # 
  # ranked_recipe <- 
  #   recipe(formula = Class ~ ., data = dtraining_ranked) %>% 
  #   step_string2factor(one_of("Class")) 
  # 
  # ranked_workflow <- 
  #   workflow() %>% 
  #   add_recipe(ranked_recipe) %>% 
  #   add_model(spec)
  # 
  # # Tuning
  # set.seed(14541)
  # ranked_tune <-
  #   tune_grid(ranked_workflow, 
  #             resamples = ranked_folds, 
  #             grid = 20)
  # 
  
  
  
  
  
  
  
}